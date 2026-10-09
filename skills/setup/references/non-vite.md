# Non-Vite Entry-File Setup

Read by `/twd:setup` Step 4, Branch B, when the project is provably non-Vite. Insert the block BEFORE the app mount code.

The guard must be a value the bundler folds to a constant at build time, or the test files and twd-js ship in production as dead lazy chunks.

**Angular** — guard on a `TWD_ENABLED` constant from `angular.json`'s `define`. **Never `isDevMode()`**: it is a runtime function call, so esbuild keeps the branch and every `await import()` in it (about 580 K of dead chunks, React included, in a typical app):

```typescript
// src/main.ts — Angular path
// Replaced at build time by the `define` option in angular.json.
// Declared as possibly undefined so a missing `define` cannot throw at module scope.
declare const TWD_ENABLED: boolean | undefined;

if (typeof TWD_ENABLED !== 'undefined' && TWD_ENABLED) {
  const { initTWD } = await import('twd-js/bundled');
  const tests = {
    './twd-tests/example.twd.test.ts': () => import('./twd-tests/example.twd.test'),
  };
  initTWD(tests, { open: true, position: 'left' });
} else if (typeof TWD_ENABLED === 'undefined') {
  console.warn('[TWD] TWD_ENABLED is not defined — add the `define` option to angular.json.');
}
```

And in `angular.json`, under `projects.<name>.architect.build` — off by default, on for `development` only:

```jsonc
"options": {
  "define": { "TWD_ENABLED": "false" }
},
"configurations": {
  "development": {
    "define": { "TWD_ENABLED": "true" }
  }
}
```

Keep the `typeof` check. A bare `if (TWD_ENABLED)` throws at module scope when a build configuration lacks the `define`, before `bootstrapApplication`, and the page renders nothing. Angular has no `import.meta.glob`, so list each test file in `tests` by hand, and add new files there as they are written.

**Webpack / CRA** — guard on `process.env.NODE_ENV` and discover tests with `require.context`:

```javascript
// src/index.{js,tsx} — Webpack path
if (process.env.NODE_ENV === 'development') {
  const context = require.context('./', true, /\.twd\.test\.ts$/);
  const tests = {};
  context.keys().forEach((key) => {
    tests[key] = async () => Promise.resolve(context(key));
  });

  const { initTWD } = await import('twd-js/bundled');
  initTWD(tests, {
    open: true,
    position: 'left',
    serviceWorker: true,
    serviceWorkerUrl: '/mock-sw.js',
  });
}
```

If the project also runs Jest, keep it off the TWD files (`--testPathIgnorePatterns=src/twd-tests`).

> **Non-Vite, non-root base path:** set `serviceWorkerUrl` to `'/BASE/mock-sw.js'`. The Vite plugin handles base-prefixing itself — do NOT pre-prefix `serviceWorkerUrl` in the plugin options.
