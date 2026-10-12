---
name: setup
description: Configures TWD for a project — detects settings, generates .claude/twd-patterns.md, installs twd-js and twd-cli, writes twd.config.json, and wires up the twd() Vite plugin (or the manual initTWD entry-file approach for non-Vite projects)
disable-model-invocation: true
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash(npm install *), Bash(npx twd-js init *), Bash(npx twd-cli run), Bash(curl -s *), Bash(git symbolic-ref *), Bash(git -C * symbolic-ref *), AskUserQuestion]
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

   The `isVite` flag drives entry-file and plugin decisions in Step 4. Vite-based projects (the default and most common case) use the new `twd()` Vite plugin (auto-injects `initTWD` via a virtual module); non-Vite projects (Angular CLI, Webpack/CRA) fall back to a manual `initTWD(...)` block in the entry file, behind a build-time guard (`TWD_ENABLED` define for Angular, `process.env.NODE_ENV` for Webpack).

   Edge case — Astro: Astro projects use Vite under the hood but configure plugins in `astro.config.mjs` under `vite.plugins`. If `astro.config.*` exists, treat as Vite (`isVite = true`) and adapt Step 4 sub-step 4 to write into `astro.config.mjs`'s `vite.plugins` block.

   For non-Vite projects, read the dev port from the framework config instead — Angular CLI: `angular.json` → `projects.<name>.architect.serve.options.port`, default `4200`. The App URL (Step 2) and `twd.config.json`'s `url` (Step 4) must use that same port.

3. **`index.html`** — detect entry point from `<script>` src attribute

4. **Glob for `src/services/`, `src/api/`, `src/lib/api`** — detect API/services folder

5. **Check if `public/` directory exists** — confirm public folder name

6. **Detect client state management** from `package.json` dependencies:
   - `zustand` → Zustand
   - `@reduxjs/toolkit` or `redux` → Redux (note: RTK Query's cache is separate from the Redux store — see #7)
   - `jotai` → Jotai
   - `pinia` → Pinia
   - `valtio` → Valtio

7. **Detect server-state caches** from `package.json` dependencies:
   - `@tanstack/react-query`, `@tanstack/vue-query`, `@tanstack/solid-query`, `@tanstack/angular-query-experimental` → TanStack Query
   - `react-query` → React Query v3 (legacy)
   - `swr` → SWR
   - `@apollo/client` → Apollo Client
   - `urql`, `@urql/preact`, `@urql/svelte` → urql
   - `@reduxjs/toolkit` **with** `createApi`/`fetchBaseQuery` usage somewhere under `src/` (grep `src/` for `createApi(` or `fetchBaseQuery(`) → RTK Query

   These libraries cache fetched data at the module level. Because `twd.visit(...)` is an SPA navigation (no page reload), the cache survives across tests and the **second** test against a fetching page will short-circuit on cached data instead of calling `fetch` — meaning TWD mocks never match and tests fail with misleading "rule not executed" errors. Step 2 Batch 2 asks the user how to reset whichever cache is in use.

8. **Check if `.claude/twd-patterns.md` already exists** — offer to update vs overwrite. When updating, replace an old `### Relay Commands` section with Runner Commands and add any missing Project Configuration lines (App URL, Dev command, Default branch, Type-check command, Closing run).

9. **Dev command** — scan `package.json` scripts for a companion service the app needs before it renders: a `serve`, `serve:dev`, `mock*` or `api*` script, or anything invoking `json-server`. If one exists and a script starts both (typically `serve:dev`), the dev command is `npm run serve:dev`; otherwise `npm run dev`.

10. **Default branch** — `git symbolic-ref --short refs/remotes/origin/HEAD`, strip `origin/`. Fall back to `main` when there is no remote.

11. **Runner state** — is `twd-cli` in `devDependencies`, does `twd.config.json` exist (read it if so), and does `package.json` already have a `test:ci` script?

12. **Type-check command** — only when the project has a `tsconfig*.json`. A `typecheck` or `type-check` script in `package.json` → `npm run <it>`. Otherwise `npx vue-tsc --noEmit -p tsconfig.app.json` for Vue, `npx tsc --noEmit -p tsconfig.app.json` when that file exists, else `npx tsc --noEmit`. The twd agent runs it on the tests it writes before the first browser run. No TypeScript → `none`.

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
> - Dev command: `npm run serve:dev`
> - Type-check command: `npx tsc --noEmit -p tsconfig.app.json`
> - App URL: `http://localhost:5173`
> - Public folder: `public/`
> - API services: `src/services/`
> - CSS library: MUI
> - Client state management: Zustand
> - Server-state cache: TanStack Query
>
> Does anything look wrong, or should I continue?

Omit the "Client state management" or "Server-state cache" line entirely when nothing was detected for that category — don't print `none`.

If `isVite` is false, replace the "Build tool" line with `Build tool: non-Vite (Angular CLI / Webpack / unknown — will use manual setup)` so the user knows the skill is taking the manual path.

### Batch 2: Testing concerns (need user input)

After confirming batch 1, use `AskUserQuestion` for each of these that requires user input:

1. **CSS library docs** (only if a CSS library was detected): Where are the docs? (URL, local path, or "skip")
2. **Auth middleware**: Does your project have route-based auth/permissions? If yes, briefly describe the pattern.
3. **Third-party modules**: Does your project use external services that need mocking in tests? (e.g., Auth0, Stripe, analytics)
   - If yes: Which modules and how are they imported?
   - The agent needs this to know what to Sinon-stub in tests — "test what you own, mock what you don't"
4. **Client state reset** (only if a client state library was detected in Step 1 #6): How do you reset the store? (e.g., `useStore.setState(initialState)`, `store.$reset()`)
   - TWD runs without page reloads — store state persists between tests and must be reset in beforeEach

5. **Server-state cache reset** (only if a server-state cache was detected in Step 1 #7): Present this with `AskUserQuestion`:

   > Your project uses **DETECTED_LIB**. TWD navigations are SPA-style, so the in-memory query cache lives across tests. **Without resetting it, the second test against a fetching page won't actually hit the network**, and your mocks will look broken when they aren't.
   >
   > The fix is to expose the cache as a module-level singleton and clear it in `beforeEach`. How do you want to handle this?
   > - **I already have the singleton — show me where** (ask for the import path, e.g. `#/query-client` or `src/lib/query-client.ts`)
   > - **Generate the pattern for me** (skill scaffolds `src/query-client.ts` / `src/apollo-client.ts` / etc. and notes the entry-file refactor needed)
   > - **Skip for now** (user wants to handle it later; skip QUERY_CACHE_RESET in `twd-patterns.md` but still write the "Server-State Cache" section as a heads-up)

   Record the chosen import path so it can be used in the generated `twd-patterns.md` (next step).

## Step 3: Generate `.claude/twd-patterns.md`

Create the `.claude/` directory if it doesn't exist, then write `.claude/twd-patterns.md` with the following sections. **Only include sections that are relevant** — omit sections that don't apply.

````markdown
# TWD Project Patterns

## Project Configuration

- **Framework**: FRAMEWORK
- **Vite base path**: BASE_PATH
- **Dev server port**: PORT
- **App URL**: APP_URL
- **Dev command**: DEV_COMMAND
- **Default branch**: DEFAULT_BRANCH
- **Entry point**: ENTRY_FILE
- **Public folder**: PUBLIC_DIR
- **Type-check command**: TYPECHECK_COMMAND
- **Closing run**: full suite

### Runner Commands

twd-cli drives its own headless browser — only the dev server has to be up (`DEV_COMMAND`).

```bash
# Run all tests
npm run test:ci

# Run specific tests by name (matches "suite > test", case-insensitive; repeatable)
npx twd-cli run --test "should render the list"
npx twd-cli run --test "should create" --test "should show the error"

# Only the tests this branch added or changed
npx twd-cli run --changed-since origin/DEFAULT_BRANCH

# Record a run to video (one clip per matched test, needs ffmpeg)
npx twd-cli run --record --test "should render the list"
```

Every run writes `.twd/report/`: `run.json` (the result), `summary.md` and `index.html`. The folder is replaced on each run.

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
  // STORE_RESET (only if a client state library detected — e.g., useStore.setState(initialState), store.$reset())
  // QUERY_CACHE_RESET (only if a server-state cache detected — see "Server-State Cache" section below)
  // SINON_RESTORE (only if third-party modules need stubbing — Sinon.restore())
  // AUTH_SETUP (only if auth middleware detected)
  // THIRD_PARTY_STUBS (only if third-party modules detected — e.g., Sinon.stub(authModule, 'useAuth').returns(...))
});

afterEach(() => {
  twd.clearRequestMockRules();
});
```

## Server-State Cache

This project uses **SERVER_STATE_LIB**. Because `twd.visit(...)` is an SPA navigation (no page reload), the cache survives between tests. Tests **must** clear it in `beforeEach`, otherwise loaders/queries will return stale cached data and your TWD mocks will never match — failures show up as "rule was not executed" even though the mock is registered correctly.

The cache is exposed as a module-level singleton at: `USER_PATH`

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

See the twd skill's `test-api.md` ("Module Stubbing with Sinon") for the default-export object pattern required for ESM stubbing.

## Portals and Dialogs

Use `screenDomGlobal` instead of `screenDom` for elements rendered in portals (modals, dropdowns, tooltips):

```typescript
import { screenDomGlobal } from "twd-js";
const modal = screenDomGlobal.getByRole("dialog");
```
````

### Template rules:
- If base path is `/`, simplify visit paths to just `await twd.visit("/page")`
- `APP_URL` is `http://localhost:PORT` plus `BASE_PATH` when it is not `/` (e.g. `http://localhost:5173/admin/`)
- `DEV_COMMAND`, `DEFAULT_BRANCH` and `TYPECHECK_COMMAND` come from Step 1 items 9, 10 and 12
- `Closing run: full suite` is always written; the user changes it to `CI` to let CI run the full suite instead
- Omit the "Auth Middleware" section entirely if no auth
- Omit the "Third-Party Modules" section entirely if no external modules
- Omit the "CSS / Component Library" section if none detected
- Omit the "API Service Types" section if no services folder found
- Omit the `STORE_RESET` comment in beforeEach if no client state library detected
- Omit the `QUERY_CACHE_RESET` comment in beforeEach if no server-state cache detected
- Omit the "Server-State Cache" section if no server-state cache detected
- Substitute `QUERY_CACHE_RESET` using the reset table in `references/server-state-cache.md` (read it only when a server-state cache was detected). Replace the placeholder `// QUERY_CACHE_RESET` comment with the actual import + reset line when the user provided a path or accepted scaffolding (don't leave it as a comment in that case); keep it as a `// QUERY_CACHE_RESET — TODO ...` comment if the user chose "Skip for now"
- Omit the `AUTH_SETUP` comment in beforeEach if no auth middleware
- Omit the `THIRD_PARTY_STUBS` comment in beforeEach if no third-party modules
- Omit `Sinon.restore()` in beforeEach if no third-party modules need stubbing — Sinon is ONLY needed when the user has external modules to stub

## Step 4: Install and Wire TWD

Using Step 1 item 11 and the entry-file and Vite-config checks, list which of the sub-steps below are already done, then offer only the missing ones. An existing TWD install is the normal case when upgrading — it still needs `twd-cli`, `twd.config.json` and `test:ci` if those are missing.

1. `npm install --save-dev twd-js twd-cli` — skip packages already in `devDependencies`.

   Both are dev-only: `twd-js` is loaded behind a dev guard the bundler folds at build time and `twd-cli` is the test runner. They must NOT land in `dependencies`.
2. `npx twd-js init PUBLIC_DIR --save`
3. Configure the entry point. **Before modifying the entry file, search it for an existing `initTWD(` call.** If found, the project has manual boilerplate from an earlier setup. On the Vite path ask via `AskUserQuestion`:

   > Existing manual `initTWD` block found in your entry file. Remove it and rely on the `twd()` Vite plugin?

   If the user agrees, delete that block. **Leave any `createBrowserClient(` block and any `twdRemote()` plugin exactly as they are** — they belong to twd-relay, which this skill neither installs nor removes.

   #### Branch A — Vite project (`isVite = true`, preferred path)

   **Do not modify the entry file.** The `twd()` plugin (sub-step 4) mounts the sidebar through a virtual module and an injected `<script type="module">` tag, so `main.{ts,tsx}` ends up with no TWD-specific code.

   #### Branch B — non-Vite project (`isVite = false`)

   Read `references/non-vite.md` and follow it. It has the Angular block (guarded by a `TWD_ENABLED` define in `angular.json`) and the Webpack/CRA block (guarded by `process.env.NODE_ENV`, tests found with `require.context`). The one rule to hold even without it: the guard must fold to a constant at build time — never `isDevMode()` — or twd-js and every test file ship in the production build.

4. Add the Vite plugin — **Vite projects only.** Skip for non-Vite projects.

   ```typescript
   import { twd } from 'twd-js/vite-plugin';

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
   ]
   ```

   `twd()` auto-discovers test files (`import.meta.glob`-based), injects the sidebar `<script>` into `index.html`, and respects Vite `base` for both the script src and the default `serviceWorkerUrl`. It only runs in `vite dev` (`apply: 'serve'`); production builds are unaffected. Full reload on test-file edits is built in.

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

5. **Scaffold server-state cache singleton** — only if a server-state cache was detected in Step 1 #7 AND the user picked "Generate the pattern for me" in Step 2 Batch 2 #5. Skip otherwise.

   Follow "Scaffolding the singleton" in `references/server-state-cache.md`: it has the singleton file and the entry-file refactor for each library. Show the diff and confirm before applying. Then point `USER_PATH` in `twd-patterns.md` at the new file.

6. **Write `twd.config.json`** at the project root. Two keys, and only two:

   ```json
   { "url": "APP_URL", "coverage": false }
   ```

   `coverage` is `false` because twd-cli collects coverage by default and prints `No code coverage data found.` on every run until instrumentation is set up — `/twd:ci-setup` turns it on when the user wants coverage. Everything else is a twd-cli default. If the file already exists, show it and merge: set `url` only if it is missing, never overwrite other keys.

7. **Add the `test:ci` script** to `package.json`: `"test:ci": "npx twd-cli run"`. If a different `test:ci` already exists, show it and ask before replacing it.

8. **Ignore `.twd/`.** Every `twd-cli run` writes its report folder, `.twd/report/`, and rewrites it on the next run, so it must never be committed. Read `.gitignore` and append this line unless `.twd` or `.twd/` is already listed:

   ```
   .twd/
   ```

   If `.gitignore` does not exist, create it with that single line. If `twd.config.json` sets `report.dir` outside `.twd/`, ignore that folder too.

9. Write a **scaffold-only** first test file at `src/twd-tests/hello.twd.test.ts` (create the `src/twd-tests/` directory if needed). The file must contain **only empty `it` blocks** — this is a setup skill, NOT a test-writing skill. Do NOT invent assertions, selectors, or page content. Do NOT add Sinon unless the user explicitly configured third-party modules that need stubbing. Use the beforeEach/afterEach from the generated `twd-patterns.md`.

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

   > **Rules for this scaffold**: Only include `Sinon.restore()` in beforeEach if third-party modules were configured. Only include client store reset if a client state library was configured. Only include the server-state cache reset (e.g. `queryClient.clear()`) if a server-state cache was configured AND the user provided a path or accepted scaffolding (sub-step 5). The `it` blocks must be empty with a comment pointing to the `/twd` skill. If the user specified a different test location, use that instead of `src/twd-tests/`.

10. **Verify the wiring with one run.** Probe the app URL once:

    ```bash
    curl -s --max-time 3 -o /dev/null -w '%{http_code}' APP_URL
    ```

    - **Any HTTP status** — the dev server is up. Run `npx twd-cli run`, then read `.twd/report/run.json`. `"outcome": "passed"` with the scaffold's tests listed means the sidebar mounted, the tests were discovered and the runner reached them: setup works. On `interrupted`, `error.message` names what is missing — a sidebar that never appeared means the `twd()` plugin (or the entry-file block) is not active, a `No tests matched` or empty run means `testFilePattern` (or the Angular `tests` object) does not cover the scaffold. Fix it and run once more.
    - **`000`** — nothing is serving. Do not start the server yourself and do not poll. Tell the user to start it with `DEV_COMMAND` and run `npm run test:ci` to confirm.

    The scaffold's `it` blocks are empty, so a pass proves the wiring, not the app.

Only run steps the user approves. Show what each step does before executing.

## Output

When done, summarize:
- Where the config file was written
- What values were detected vs asked
- **Which integration path was used** — Vite plugin (`twd()` in `vite.config.*`, no TWD code in the entry file) or manual (`initTWD(...)` block in the entry file). For Vite projects with a non-root `base`, mention that the plugin auto-prefixes the script src and `serviceWorkerUrl`.
- **Server-state cache handling** (if applicable) — which library, the import path used in `QUERY_CACHE_RESET`, and whether the singleton was scaffolded or already existed
- **Runner** — twd-cli installed, `twd.config.json` written or merged (show its contents), `test:ci` added or kept, `.twd/` added to `.gitignore` or already there
- What setup steps were completed
- **Verification run** — its `outcome` from `run.json`, or that the dev server was not running and the user should run `npm run test:ci` once it is
- Next steps, in this order:
  1. If the verification run did not happen: start the app with `DEV_COMMAND` and run `npm run test:ci`
  2. Ask for tests (the `twd` skill writes and runs them headlessly)
  3. Optionally run `/twd:ci-setup` for a GitHub Actions workflow
