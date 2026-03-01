---
name: setup
description: Configure TWD for your project — detects settings and generates .claude/twd-patterns.md
disable-model-invocation: true
allowed-tools: [Read, Write, Glob, Grep, Bash(npm install *), Bash(npx twd-js init *)]
---

# TWD Project Setup

You are configuring TWD (Test While Developing) for this project. Your job is to detect project settings, ask questions for what can't be auto-detected, and generate a `.claude/twd-patterns.md` configuration file.

## Step 1: Auto-Detect Project Settings

Read these files to pre-fill answers (read all in parallel):

1. **`package.json`** — detect framework from dependencies:
   - `react` / `react-dom` → React
   - `vue` → Vue
   - `@angular/core` → Angular
   - `solid-js` → Solid
   - Also detect CSS/component libraries: `@mui/material`, `@chakra-ui/react`, `antd`, `@mantine/core`, `vuetify`, `primevue`, `element-plus`, `@angular/material`

2. **`vite.config.ts`** (or `.js`, `.mjs`) — detect:
   - `base` field (Vite base path, default `/`)
   - `server.port` (dev server port, default `5173`)

3. **`index.html`** — detect entry point from `<script>` src attribute

4. **Glob for `src/services/`, `src/api/`, `src/lib/api`** — detect API/services folder

5. **Check if `public/` directory exists** — confirm public folder name

6. **Check if `.claude/twd-patterns.md` already exists** — offer to update vs overwrite

## Step 2: Ask Questions

Use the detected values as defaults. Ask the user to confirm or correct:

1. **Framework**: Detected X — is this correct? (React / Vue / Angular / Solid)
2. **Vite base path**: Detected `BASE` — is this correct? (default `/`)
3. **Public folder**: Detected `public/` — is this correct?
4. **Dev server port**: Detected `PORT` — is this correct? (default `5173`)
5. **Entry point file**: Detected `FILE` — is this correct?
6. **API services folder**: Detected `FOLDER` — where are your API types/services? (path or "none")
7. **CSS/component library**: Detected `LIB` — is this correct? (or "none")
   - **If a CSS library was detected**: Where are the docs? (URL, local path, or "skip")
8. **Auth middleware**: Does your project have route-based auth/permissions? (yes/no)
   - **If yes**: Briefly describe the pattern (e.g., "useAuth hook checks permissions per route")
9. **Third-party modules**: Does your project use external services that need to be mocked/stubbed in tests? (yes/no)
   - **If yes**: Which modules? (e.g., Auth0, Stripe, ConfigCat, analytics SDKs, feature flag services)
   - For each module: How is it imported? (e.g., `import { useAuth0 } from '@auth0/auth0-react'`)
   - The agent needs this to know what to Sinon-stub in tests — "test what you own, mock what you don't"

Skip questions where auto-detection is confident (e.g., framework is obvious from package.json).

## Step 3: Generate `.claude/twd-patterns.md`

Create the `.claude/` directory if it doesn't exist, then write `.claude/twd-patterns.md` with the following sections. **Only include sections that are relevant** — omit sections that don't apply.

```markdown
# TWD Project Patterns

## Project Configuration

- **Framework**: FRAMEWORK
- **Vite base path**: BASE_PATH
- **Dev server port**: PORT
- **Entry point**: ENTRY_FILE
- **Public folder**: PUBLIC_DIR

### Relay Commands

```bash
# Run all tests (default — use this if base path is / and port is 5173)
npx twd-relay run

# Run all tests (custom config)
npx twd-relay run --port PORT --path "BASE_PATH__twd/ws"
```

## Standard Imports

```typescript
import { twd, userEvent, screenDom, expect } from "twd-js";
import { describe, it, beforeEach, afterEach } from "twd-js/runner";
// Project-specific imports go here (added by user)
```

## Visit Paths

All `twd.visit()` calls must include the base path prefix:

```typescript
await twd.visit("BASE_PATH");
await twd.visit("BASE_PATHsome-page");
```

## Standard beforeEach / afterEach

```typescript
beforeEach(() => {
  twd.clearRequestMockRules();
  twd.clearComponentMocks();
  Sinon.restore();
  // AUTH_SETUP (if applicable)
  // THIRD_PARTY_STUBS (if applicable — e.g., Sinon.stub(authModule, 'useAuth').returns(...))
});

afterEach(() => {
  twd.clearRequestMockRules();
});
```

## API Service Types

Service/API types are located in: `API_FOLDER`

Read files in this folder to understand endpoint URLs and response shapes when writing mock data.

## CSS / Component Library

- **Library**: CSS_LIB
- **Docs**: CSS_DOCS_LOCATION

When writing tests, refer to library docs for correct ARIA roles and component structure.

## Auth Middleware

AUTH_DESCRIPTION

### Route → Permission Mapping

| Route | Required Permissions |
|-------|---------------------|
| (to be filled by developer) | |

## Third-Party Modules

"Test what you own, mock what you don't." These external modules should be stubbed in tests:

| Module | Import Pattern | Stub Strategy |
|--------|---------------|---------------|
| MODULE_NAME | `import { hook } from 'package'` | `Sinon.stub(moduleObj, 'hook').returns(...)` |
| (to be filled by developer) | | |

See the test-writing reference for the default-export object pattern required for ESM stubbing.

## Portals and Dialogs

Use `screenDomGlobal` instead of `screenDom` for elements rendered in portals (modals, dropdowns, tooltips):

```typescript
import { screenDomGlobal } from "twd-js";
const modal = screenDomGlobal.getByRole("dialog");
```
```

### Template rules:
- If base path is `/`, simplify visit paths to just `await twd.visit("/page")`
- If port is `5173` and base path is `/`, use `npx twd-relay run` (no flags)
- Omit the "Auth Middleware" section entirely if no auth
- Omit the "Third-Party Modules" section entirely if no external modules
- Omit the "CSS / Component Library" section if none detected
- Omit the "API Service Types" section if no services folder found

## Step 4: Optionally Run Setup

After generating the config file, check if TWD is already installed. If not, ask the user if they want to run setup now:

1. `npm install twd-js`
2. `npm install --save-dev twd-relay`
3. `npx twd-js init PUBLIC_DIR --save`
4. Configure entry point with relay client (show the complete DEV block from `references/setup.md` Step 3, including the `initTWD` call and the `VITE_ENABLE_TWD_RELAY` guarded `createBrowserClient` block — all inside one `import.meta.env.DEV` guard)
5. Add Vite plugins: `twdHmr()` from `twd-js/vite-plugin` and `twdRemote() as PluginOption` from `twd-relay/vite` (with `import type { PluginOption } from 'vite'`)
6. Write a first test file

Only run steps the user approves. Show what each step does before executing.

## Output

When done, summarize:
- Where the config file was written
- What values were detected vs asked
- What setup steps were completed (if any)
- Next steps for the user (e.g., "Run `npm run dev` to see the TWD sidebar")
