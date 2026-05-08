---
name: setup
description: Configures TWD for a project — detects settings, generates .claude/twd-patterns.md, and wires up the twd() Vite plugin (or the manual initTWD entry-file approach for non-Vite projects)
disable-model-invocation: true
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash(npm install *), Bash(npx twd-js init *), AskUserQuestion]
---

# TWD Project Setup

You are configuring TWD (Test While Developing) for this project. Your job is to detect project settings, ask questions for what can't be auto-detected, and generate a `.claude/twd-patterns.md` configuration file.

**Default path: the `twd()` Vite plugin.** The vast majority of TWD users are on Vite, so the skill optimises for that case. Only fall back to the manual `initTWD(...)` entry-file approach when the project is provably non-Vite (no `vite` dep AND no `vite.config.*` AND no `astro.config.*` — see Step 1). When in doubt, prefer the Vite path and confirm with the user before deviating.

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

   Also classify the project as Vite vs non-Vite:

   ```
   isVite = (
     package.json declares `vite` as a dep
     OR
     any of (vite.config.ts, vite.config.js, vite.config.mjs) exists at the project root
   )
   ```

   The `isVite` flag drives entry-file and plugin decisions in Step 4. Vite-based projects (the default and most common case) use the new `twd()` Vite plugin (auto-injects `initTWD` via a virtual module); non-Vite projects (Angular CLI, Webpack/CRA) fall back to the manual `if (import.meta.env.DEV) { initTWD(...) }` block in the entry file.

   Edge case — Astro: Astro projects use Vite under the hood but configure plugins in `astro.config.mjs` under `vite.plugins`. If `astro.config.*` exists, treat as Vite (`isVite = true`) and adapt Step 4 sub-step 5 to write into `astro.config.mjs`'s `vite.plugins` block.

3. **`index.html`** — detect entry point from `<script>` src attribute

4. **Glob for `src/services/`, `src/api/`, `src/lib/api`** — detect API/services folder

5. **Check if `public/` directory exists** — confirm public folder name

6. **Detect state management** from `package.json` dependencies:
   - `zustand` → Zustand
   - `@reduxjs/toolkit` or `redux` → Redux
   - `jotai` → Jotai
   - `pinia` → Pinia

7. **Check if `.claude/twd-patterns.md` already exists** — offer to update vs overwrite

## Step 2: Ask Questions

**IMPORTANT: Use the `AskUserQuestion` tool for ALL questions.** This provides an interactive UI experience. Never dump questions as a plain numbered list in text output.

Present auto-detected values as a summary first, then ask questions in two batches:

### Batch 1: Project basics (confirm auto-detected values)

**Do NOT ask individual questions for values you already detected.** Show a single summary of all detected values and ask "Does anything look wrong?" using `AskUserQuestion`. The user only needs to respond if something is incorrect. Example:

> Here's what I detected:
> - Framework: React
> - Build tool: Vite
> - Vite base path: `/`
> - Dev server port: `5173`
> - Entry point: `src/main.tsx`
> - Public folder: `public/`
> - API services: `src/services/`
> - CSS library: MUI
> - State management: Zustand
>
> Does anything look wrong, or should I continue?

If `isVite` is false, replace the "Build tool" line with `Build tool: non-Vite (Angular CLI / Webpack / unknown — will use manual setup)` so the user knows the skill is taking the manual path.

### Batch 2: Testing concerns (need user input)

After confirming batch 1, use `AskUserQuestion` for each of these that requires user input:

1. **CSS library docs** (only if a CSS library was detected): Where are the docs? (URL, local path, or "skip")
2. **Auth middleware**: Does your project have route-based auth/permissions? If yes, briefly describe the pattern.
3. **Third-party modules**: Does your project use external services that need mocking in tests? (e.g., Auth0, Stripe, analytics)
   - If yes: Which modules and how are they imported?
   - The agent needs this to know what to Sinon-stub in tests — "test what you own, mock what you don't"
4. **State reset** (only if state management was detected): How do you reset the store? (e.g., `useStore.setState(initialState)`, `store.$reset()`)
   - TWD runs without page reloads — store state persists between tests and must be reset in beforeEach

## Step 3: Generate `.claude/twd-patterns.md`

Create the `.claude/` directory if it doesn't exist, then write `.claude/twd-patterns.md` with the following sections. **Only include sections that are relevant** — omit sections that don't apply.

````markdown
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
  // SINON_RESTORE (only if third-party modules need stubbing — Sinon.restore())
  // STORE_RESET (only if state management detected — e.g., useStore.setState(initialState), store.$reset())
  // AUTH_SETUP (only if auth middleware detected)
  // THIRD_PARTY_STUBS (only if third-party modules detected — e.g., Sinon.stub(authModule, 'useAuth').returns(...))
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
````

### Template rules:
- If base path is `/`, simplify visit paths to just `await twd.visit("/page")`
- If port is `5173` and base path is `/`, use `npx twd-relay run` (no flags)
- Omit the "Auth Middleware" section entirely if no auth
- Omit the "Third-Party Modules" section entirely if no external modules
- Omit the "CSS / Component Library" section if none detected
- Omit the "API Service Types" section if no services folder found
- Omit the `STORE_RESET` comment in beforeEach if no state management library
- Omit the `AUTH_SETUP` comment in beforeEach if no auth middleware
- Omit the `THIRD_PARTY_STUBS` comment in beforeEach if no third-party modules
- Omit `Sinon.restore()` in beforeEach if no third-party modules need stubbing — Sinon is ONLY needed when the user has external modules to stub

## Step 4: Optionally Run Setup

After generating the config file, check if TWD is already installed. If not, ask the user if they want to run setup now:

1. `npm install --save-dev twd-js`
2. `npm install --save-dev twd-relay`

   Both packages are dev-only — `twd-js` is loaded behind `import.meta.env.DEV` (or the equivalent dev guard) and `twd-relay` only attaches to the dev server. They must NOT land in `dependencies`, otherwise they'll be bundled into production builds.
3. `npx twd-js init PUBLIC_DIR --save`
4. Configure entry point — **insert this DEV block BEFORE the existing app mount code** (before `createRoot`, `createApp`, etc.). The block to insert depends on `isVite`.

   **Before modifying the entry file, search it for any existing `initTWD(` OR `createBrowserClient(` call.** If either is found, the project already has manual boilerplate from a previous setup. Ask the user via `AskUserQuestion`:

   > Existing manual TWD setup detected in your entry file (`initTWD` and/or `createBrowserClient`). Remove it now and rely on the `twd()` + `twdRemote()` Vite plugins?

   If the user agrees (Vite path), delete the old block(s) entirely — both `initTWD(...)` and `createBrowserClient(...)` go away; the entry file ends up with no TWD-specific code at all (see Branch A below). If the user declines, leave the entry file alone and surface this warning in the post-setup summary:

   > You've kept the manual `createBrowserClient` block. With `twd-relay`'s auto-connect plugin enabled, two browser clients will connect (you'll see a duplicate browser in the relay logs). Set `autoConnect: false` on `twdRemote()` if you want to keep the manual block.

   #### Branch A — Vite project (`isVite = true`, preferred path)

   On the Vite path, **do not modify the entry file.** Both pieces are now plugins:

   - `twd()` (sub-step 5) auto-mounts the sidebar via a virtual module + injected `<script type="module">` tag.
   - `twdRemote()` (sub-step 5) defaults to `autoConnect: true` and auto-injects a `<script>` that calls `createBrowserClient(...).connect()` against the resolved relay URL (`base + '/__twd/ws'`).

   So `main.{ts,tsx}` ends up with **zero** TWD-specific code on the Vite path — no `initTWD(...)`, no `createBrowserClient(...)`. If the existing entry file already contains either, the duplicate-setup detection above offers to delete it.

   #### Branch B — non-Vite project (`isVite = false`)

   Keep the full manual block. `import.meta.env.DEV` may not exist in non-Vite environments, so guard it:

   ```typescript
   // src/main.{ts,tsx} — non-Vite path (Webpack/CRA, etc.)
   if (typeof import.meta !== 'undefined' && import.meta.env?.DEV) {
     const { initTWD } = await import('twd-js/bundled');
     // For projects without import.meta.glob support, build the tests object manually:
     const tests = {
       './twd-tests/example.twd.test.ts': () => import('./twd-tests/example.twd.test'),
     };

     initTWD(tests, {
       open: true,
       position: 'left',
       serviceWorker: true,
       serviceWorkerUrl: '/mock-sw.js',
     });

     const { createBrowserClient } = await import('twd-relay/browser');
     const client = createBrowserClient({ url: `${window.location.origin}/__twd/ws` });
     client.connect();
   }
   ```

   For **Angular** specifically, use `isDevMode()` from `@angular/core` instead of `import.meta.env.DEV`:

   ```typescript
   // src/main.ts — Angular path
   import { isDevMode } from '@angular/core';

   if (isDevMode()) {
     const { initTWD } = await import('twd-js/bundled');
     const tests = {
       './twd-tests/example.twd.test.ts': () => import('./twd-tests/example.twd.test'),
     };
     initTWD(tests, { open: true, position: 'left' });

     const { createBrowserClient } = await import('twd-relay/browser');
     const client = createBrowserClient({ url: `${window.location.origin}/__twd/ws` });
     client.connect();
   }
   ```

   > **Adjustments (non-Vite only)**: If the dev server is served from a non-root base path, update `serviceWorkerUrl` to `'/BASE/mock-sw.js'` and the relay URL to `` `${window.location.origin}/BASE/__twd/ws` ``. The Vite-path plugin handles base-prefixing automatically — do NOT pre-prefix `serviceWorkerUrl` in the plugin options.

5. Add Vite plugins — **Vite projects only.** For non-Vite projects (`isVite = false`), skip this sub-step entirely; there is no Vite config to modify.

   ```typescript
   import { twd } from 'twd-js/vite-plugin';
   import { twdRemote } from 'twd-relay/vite';
   import type { PluginOption } from 'vite';

   // Add to plugins array (preserve existing plugin order; insert at the end):
   plugins: [
     // ... other plugins (react(), tailwindcss(), istanbul(), etc.)
     twd({
       testFilePattern: '/**/*.twd.test.{ts,tsx}', // see framework defaults below
       open: true,
       position: 'left',
       // serviceWorker / serviceWorkerUrl defaults work; pass user overrides here.
       // Other options the user wants (search, theme, rootSelector) go here too.
     }),
     twdRemote() as PluginOption,
   ]
   ```

   `twd()` auto-discovers test files (`import.meta.glob`-based), injects the sidebar `<script>` into `index.html`, and respects Vite `base` for both the script src and the default `serviceWorkerUrl`. It only runs in `vite dev` (`apply: 'serve'`); production builds are unaffected. The old `twdHmr()` plugin is **no longer needed** — full-reload on test-file edits is built into `twd()`.

   `twdRemote()` defaults to `autoConnect: true`, so it injects a `<script>` tag that connects the browser client to the relay — no entry-file snippet needed. The plugin resolves both the relay-server path and the injected client path from the same formula (`options.path ?? base + '/__twd/ws'`), so they cannot drift on a non-default `base`. Pass `autoConnect: false` if you want to wire `createBrowserClient` manually (rare; only useful if you need to subscribe to client events). You can also forward client options: `twdRemote({ autoConnect: { reconnect: false, log: true } })`.

   #### `testFilePattern` defaults by framework

   | Detected framework | Recommended `testFilePattern` |
   |---|---|
   | React | `'/**/*.twd.test.{ts,tsx}'` |
   | Vue | `'/**/*.twd.test.ts'` |
   | Solid | `'/**/*.twd.test.{ts,tsx}'` |
   | Other Vite-native | `'/**/*.twd.test.ts'` (default) |

   #### `TwdPluginOptions` reference

   | Option | Type | Default | Notes |
   |---|---|---|---|
   | `testFilePattern` | `string` | `/**/*.twd.test.ts` | Glob for test discovery |
   | `open` | `boolean` | `true` | Sidebar starts open |
   | `position` | `"left" \| "right"` | `"left"` | Sidebar anchor |
   | `serviceWorker` | `boolean` | `true` | Register Mock Service Worker |
   | `serviceWorkerUrl` | `string` | `/mock-sw.js` | Auto base-prefixed if user didn't set it |
   | `theme` | `Partial<TWDTheme>` | — | Sidebar theme overrides |
   | `search` | `boolean` | `false` | Show sidebar search input |
   | `rootSelector` | `string` | — | Custom screenDom root (e.g. `#my-app`) |

6. Write a **scaffold-only** first test file at `src/twd-tests/hello.twd.test.ts` (create the `src/twd-tests/` directory if needed). The file must contain **only empty `it` blocks** — this is a setup skill, NOT a test-writing skill. Do NOT invent assertions, selectors, or page content. Do NOT add Sinon unless the user explicitly configured third-party modules that need stubbing. Use the beforeEach/afterEach from the generated `twd-patterns.md`.

   Example scaffold:

   ```typescript
   import { twd, userEvent, screenDom, expect } from "twd-js";
   import { describe, it, beforeEach, afterEach } from "twd-js/runner";

   describe("App Smoke Test", () => {
     beforeEach(() => {
       twd.clearRequestMockRules();
       twd.clearComponentMocks();
     });

     afterEach(() => {
       twd.clearRequestMockRules();
     });

     it("renders the home page", async () => {
       // Use the /twd skill to write actual test content
     });
   });
   ```

   > **Rules for this scaffold**: Only include `Sinon.restore()` in beforeEach if third-party modules were configured. Only include store reset if state management was configured. The `it` blocks must be empty with a comment pointing to the `/twd` skill. If the user specified a different test location, use that instead of `src/twd-tests/`.

Only run steps the user approves. Show what each step does before executing.

## Output

When done, summarize:
- Where the config file was written
- What values were detected vs asked
- **Which integration path was used** — Vite plugin (`twd()` in `vite.config.*`, entry file only has the relay block) or manual (`initTWD(...)` block in entry file). For Vite projects with a non-root `base`, mention that the plugin auto-prefixes the script src and `serviceWorkerUrl` — no manual adjustment needed.
- What setup steps were completed (if any)
- Next steps for the user (e.g., "Run `npm run dev` to see the TWD sidebar")
