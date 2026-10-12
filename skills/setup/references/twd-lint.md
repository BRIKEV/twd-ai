# Wiring twd-lint

Read from `/twd:setup` Step 4, sub-step 8. Step 1 item 13 has already picked the path.

Install `twd-lint` with the same pinning as `twd-js` — `--save-exact` if `twd-js` is pinned to an exact version, a caret otherwise.

- **ESLint plugin:** `npm install --save-dev twd-lint`, then add one import and one entry at the end of the exported config array. `recommended` applies only to `**/*.twd.test.{ts,tsx,js,jsx}` and brings its own TypeScript parser, so it touches no other file and needs no parser setup:

  ```js
  import twd from 'twd-lint';

  export default [
    // ...existing config, unchanged
    twd.configs.recommended,
  ];
  ```

  If the array is wrapped (`defineConfig([...])`, `tseslint.config(...)`), add the entry as the last argument inside it.
- **Command:** `npm install --save-dev twd-lint` and a `"lint:twd": "twd-lint"` script — `lint:twd`, so it never clashes with a `lint` script.

Either way the twd agent runs `npx twd-lint` on the files it writes; installing it pins the version and puts it in front of the people and CI too.

With Tailwind CSS 4 in the project, check `package-lock.json` after any install: npm 11.6 can drop the `@emnapi/core` and `@emnapi/runtime` entries under `@tailwindcss/oxide-wasm32-wasi`, and `npm ci` then fails in CI with "Missing: @emnapi/core … from lock file". Restore those entries from the previous lockfile if they went missing.
