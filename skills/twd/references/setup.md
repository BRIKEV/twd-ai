# TWD Setup Reference

<!-- Package provenance: twd-js, twd-cli (npm: brikev, MIT, github.com/BRIKEV).
     All TWD code is dev-only (import.meta.env.DEV guard). -->

## Step 1: Install Packages

```bash
npm install --save-dev twd-js twd-cli
```

Both are dev-only. `twd-js` loads behind `import.meta.env.DEV`; `twd-cli` is the
runner and never ships.

## Step 2: Initialize Mock Service Worker

```bash
npx twd-js init public --save
```

Copies `mock-sw.js` into `public/`. Use the project's public folder if it has
another name.

## Step 3: Wire TWD into the app

### Vite (React, Vue, Solid, anything Vite-based)

No entry-file code. Add the plugin:

```typescript
// vite.config.ts
import { twd } from 'twd-js/vite-plugin';

export default defineConfig({
  plugins: [
    // ... other plugins
    twd({
      testFilePattern: '/**/*.twd.test.{ts,tsx}',
      open: true,
      position: 'left',
    }),
  ],
});
```

`twd()` discovers test files, mounts the sidebar through an injected
`<script>`, registers the mock service worker, and respects Vite `base`. It only
runs in `vite dev`, so production builds are untouched. If a previous setup left
an `initTWD(...)` block in the entry file, offer to delete it — the plugin
replaces it. Leave any `twdRemote()` or `createBrowserClient(` wiring
untouched; it belongs to twd-relay.

### Angular

Insert a dev-only block in `src/main.ts` **before** `bootstrapApplication(...)`,
guarded by a build-time constant — never `isDevMode()`, which is a runtime call
that leaves every lazy chunk (React included) in the production build:

```typescript
declare const TWD_ENABLED: boolean | undefined;

if (typeof TWD_ENABLED !== 'undefined' && TWD_ENABLED) {
  const { initTWD } = await import('twd-js/bundled');
  const tests = {
    './twd-tests/feature.twd.test.ts': () => import('./twd-tests/feature.twd.test'),
  };
  initTWD(tests, { open: true, position: 'left' });
} else if (typeof TWD_ENABLED === 'undefined') {
  console.warn('[TWD] TWD_ENABLED is not defined — add the `define` option to angular.json.');
}
```

Then in `angular.json` under `architect.build`: `"options": { "define": { "TWD_ENABLED": "false" } }`
and `"configurations": { "development": { "define": { "TWD_ENABLED": "true" } } }`.
Keep the `typeof` check: without it a configuration missing the `define` throws
before bootstrap and renders a blank page. Angular has no `import.meta.glob`, so
add each new test file to `tests` by hand.

### Webpack / CRA

Guard on `process.env.NODE_ENV === 'development'` and build `tests` from
`require.context('./', true, /\.twd\.test\.ts$/)`, wrapping each module in
`Promise.resolve`. Same `initTWD` call.

Under a non-root base path, pass `serviceWorkerUrl: '/BASE/mock-sw.js'`.

**initTWD options:** `open` (default `true`), `position` (`"left"` | `"right"`),
`serviceWorker` (default `true`), `serviceWorkerUrl` (default `'/mock-sw.js'`).

## Step 4: `twd.config.json`

```json
{ "url": "http://localhost:5173", "coverage": false }
```

`url` is the app URL including any base path. `coverage` stays `false` until CI
coverage is set up. If the file exists, merge rather than overwrite.

## Step 5: Ignore the report folder

Every run writes `.twd/report/` and rewrites it on the next one. Append `.twd/`
to `.gitignore` unless `.twd` or `.twd/` is already listed; create the file if
there is none.

## Step 6: Write a First Test

```typescript
// src/twd-tests/app.twd.test.ts
import { twd, screenDom } from "twd-js";
import { describe, it } from "twd-js/runner";

describe("App", () => {
  it("should render the main heading", async () => {
    await twd.visit("/");
    const heading = await screenDom.findByRole("heading", { level: 1 });
    twd.should(heading, "be.visible");
  });
});
```

Organize larger suites by domain: `src/twd-tests/auth/`, `src/twd-tests/dashboard/`,
shared mock data in `src/twd-tests/mocks/`.

## Verify Setup

Probe the app URL, then run:

```bash
curl -s --max-time 3 -o /dev/null -w '%{http_code}' http://localhost:5173
npx twd-cli run
```

Exit code 0, and `"outcome": "passed"` in `.twd/report/run.json`, means setup
is complete. To also watch runs live in a tab, see `relay.md`.
