# TWD Setup Reference

<!-- Package provenance: twd-js (npm: brikev, MIT, github.com/BRIKEV/twd),
     twd-relay (npm: brikev, MIT, github.com/BRIKEV/twd-relay).
     All TWD code is dev-only (import.meta.env.DEV guard). -->

## Step 1: Install Packages

```bash
npm install twd-js
npm install --save-dev twd-relay
```

## Step 2: Initialize Mock Service Worker

```bash
npx twd-js init public --save
```

This copies `mock-sw.js` to the `public/` directory. If the public directory has a different name (e.g., `static/`), use that path instead.

## Step 3: Configure Entry Point

The entry-file requirement now depends on whether the project uses Vite. The Vite path needs **no entry-file code at all** — both the sidebar and the relay client are wired up by Vite plugins (Step 4). Non-Vite projects (Angular CLI, Webpack/CRA, Rollup, esbuild, Rspack) keep the manual `initTWD` + `createBrowserClient` block in dev-only mode.

### Vite (Recommended — Bundled, React, Vue, Solid, anything Vite-based)

```typescript
// src/main.{ts,tsx} — Vite path
// No TWD-specific code needed in this file.
// Both twd() (sidebar) and twdRemote() (relay browser client)
// are configured in vite.config.ts (see Step 4).
```

The `twd()` plugin auto-mounts the sidebar via a virtual module and an injected `<script type="module">` tag. The `twdRemote()` plugin defaults to `autoConnect: true` and auto-connects the browser client to the relay (`base + '/__twd/ws'`). Both are dev-only via Vite's `apply: 'serve'`; production builds are untouched.

If a previous setup left an `if (import.meta.env.DEV) { ... initTWD(...) }` or `createBrowserClient(...).connect()` block in the entry file, delete it. Leaving it in place causes **two browser clients to connect** — visible in the relay logs as a duplicate browser. The fix is either delete the manual block, or set `autoConnect: false` on `twdRemote()` to keep the manual API.

### Angular (non-Vite)

Angular CLI does not use Vite at runtime, so neither plugin applies. Insert the DEV block in `src/main.ts` **before** the existing `bootstrapApplication(...)` call:

```typescript
// src/main.ts — Angular path
import { isDevMode } from '@angular/core';

if (isDevMode()) {
  const { initTWD } = await import('twd-js/bundled');
  // Angular may not support import.meta.glob — define tests manually:
  const tests = {
    './twd-tests/feature.twd.test.ts': () => import('./twd-tests/feature.twd.test'),
  };
  initTWD(tests, { open: true, position: 'left' });

  const { createBrowserClient } = await import('twd-relay/browser');
  const client = createBrowserClient({ url: `${window.location.origin}/__twd/ws` });
  client.connect();
}
```

> **Note (Angular and other non-Vite bundlers):** if your dev server is served from a non-root base path (e.g. `/my-app/`), adjust the relay client URL accordingly: `` `${window.location.origin}/my-app/__twd/ws` ``, and update `serviceWorkerUrl` to `'/my-app/mock-sw.js'`. Vite consumers do not need this — the plugin handles base-prefixing automatically.

**initTWD options (non-Vite path):**
- `open` (boolean) — sidebar open by default. Default: `true`
- `position` (`"left"` | `"right"`) — sidebar position. Default: `"left"`
- `serviceWorker` (boolean) — enable API mocking. Default: `true`
- `serviceWorkerUrl` (string) — service worker path. Default: `'/mock-sw.js'`

## Step 4: Vite Plugins

```typescript
// vite.config.ts
import { twd } from 'twd-js/vite-plugin';
import { twdRemote } from 'twd-relay/vite';

export default defineConfig({
  plugins: [
    // ... other plugins
    twd({
      testFilePattern: '/**/*.twd.test.{ts,tsx}',
      open: true,
      position: 'left',
    }),
    twdRemote(),
  ],
});
```

`twd()` (from `twd-js@1.8.0+`) auto-discovers test files, mounts the sidebar via a virtual module + injected `<script>` tag, and respects Vite `base` for both the script src and the default `serviceWorkerUrl`. The old `twdHmr()` plugin is no longer needed — full-reload on test-file edits is built in.

`twdRemote()` defaults to `autoConnect: true` and injects the relay browser client into `index.html` automatically. The relay-server path and the injected client path resolve from the same formula (`options.path ?? base + '/__twd/ws'`), so they cannot drift on a non-default `base`. Use `twdRemote({ autoConnect: false })` if you need to wire `createBrowserClient` manually — useful when subscribing to client events.

## Step 5: Write a First Test

Create a `src/twd-tests/` folder for all TWD tests. For larger projects, organize by domain (e.g., `src/twd-tests/auth/`, `src/twd-tests/dashboard/`).

```typescript
// src/twd-tests/app.twd.test.ts
import { twd, screenDom } from "twd-js";
import { describe, it } from "twd-js/runner";

describe("App", () => {
  it("should render the main heading", async () => {
    await twd.visit("/");
    const heading = screenDom.getByRole("heading", { level: 1 });
    twd.should(heading, "be.visible");
  });
});
```

**Folder structure example:**
```
src/twd-tests/
  app.twd.test.ts          # General app tests
  auth/
    login.twd.test.ts      # Auth-related tests
  dashboard/
    overview.twd.test.ts   # Dashboard domain tests
  mocks/
    users.ts               # Shared mock data
```

## Verify Setup

Use the relay command from your `.claude/twd-patterns.md` (or defaults):

```bash
# Default (works with Vite default port 5173 and base path /)
npx twd-relay run

# Custom port/base path
npx twd-relay run --port PORT --path "BASE/__twd/ws"
```

If exit code is 0 and the test passes, setup is complete.

> When the browser connects, the tab's favicon turns blue and the title gains a `[TWD]` prefix. If the user has multiple tabs open to the same origin, this is how you identify which tab is the TWD tab.
