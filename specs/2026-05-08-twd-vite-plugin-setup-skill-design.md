# Setup skill update — adopt the `twd()` Vite plugin

**Date:** 2026-05-08
**Repo:** `twd-ai`
**Skill affected:** `skills/setup/SKILL.md`
**Triggered by:** [`twd-js@1.8.0`](https://github.com/BRIKEV/twd/releases/tag/v1.8.0) shipping the `twd()` Vite plugin

## Motivation

`twd-js@1.8.0` introduced a new `twd()` Vite plugin that auto-wires TWD into a dev server. Consumers who use Vite no longer need to add the `if (import.meta.env.DEV) { initTWD(...) }` boilerplate to their entry file — the plugin handles test discovery, sidebar injection, and service-worker registration via a virtual module + `transformIndexHtml` script tag.

The `setup` skill currently scaffolds the OLD manual approach (`if (import.meta.env.DEV) { ... initTWD(...) }` in `main.tsx`) for every project. That's now wrong for Vite-based projects — they should use the plugin instead.

This spec describes the changes needed in the setup skill so it:
1. **Prefers the `twd()` Vite plugin** when the project uses Vite.
2. **Falls back to the manual `initTWD` entry-file approach** for non-Vite projects (Angular CLI, Webpack/CRA, etc.).
3. **Keeps the `twd-relay` browser-client init in the entry file** in both cases (the relay does NOT have a plugin equivalent yet — that's a future twd-relay change, not in scope here).

## What changed in `twd-js@1.8.0` — quick recap

### New plugin: `twd()` from `twd-js/vite-plugin`

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { twd } from 'twd-js/vite-plugin';

export default defineConfig({
  plugins: [
    react(),
    twd({
      testFilePattern: '/**/*.twd.test.{ts,tsx}',
      open: true,
      position: 'left',
      serviceWorker: true,
      serviceWorkerUrl: '/mock-sw.js',
    }),
  ],
});
```

Behavior:
- `apply: 'serve'` — only runs in `vite dev`. Production builds are unaffected.
- Auto-discovers test files via the `testFilePattern` glob (passed through to `import.meta.glob` internally).
- Injects a `<script type="module">` tag into `index.html` that loads a virtual module which calls `initTWD(...)` with the discovered tests + the user's options.
- **Respects Vite `base` config** — the script src and default `serviceWorkerUrl` are auto-prefixed when `base` is non-root (e.g. `/platform-admin/`). User-supplied `serviceWorkerUrl` values are NOT double-prefixed.
- Full-reload on test-file edits is automatic — the existing `twdHmr()` plugin is **no longer needed** when using `twd()`.

### `TwdPluginOptions` (full surface)

| Option | Type | Default | Notes |
|---|---|---|---|
| `testFilePattern` | `string` | `/**/*.twd.test.ts` | Glob for test discovery |
| `open` | `boolean` | `true` | Sidebar starts open |
| `position` | `"left" \| "right"` | `"left"` | Sidebar anchor |
| `serviceWorker` | `boolean` | `true` | Register Mock Service Worker |
| `serviceWorkerUrl` | `string` | `/mock-sw.js` | SW script URL (base-prefixed if user didn't set it) |
| `theme` | `Partial<TWDTheme>` | — | Sidebar theme overrides |
| `search` | `boolean` | `false` | Show sidebar search input |
| `rootSelector` | `string` | — | Custom screenDom root (e.g. `#my-app`) |

### What's still required (NOT yet automated by the plugin)

- `npx twd-js init PUBLIC_DIR --save` — manual SW file install. Auto-install is a future tier-1 follow-up in the `twd-js` roadmap; for now the setup skill must still run this step.

## Decision logic for the setup skill

The skill already detects whether `vite.config.ts` exists and reads `base`/`server.port` from it. We extend that detection to a single classification:

```
isVite = (
  package.json declares `vite` as a dep
  OR
  any of (vite.config.ts, vite.config.js, vite.config.mjs) exists at the project root
)
```

Then pick a path:

| `isVite` | Approach |
|---|---|
| ✅ true | Use `twd()` plugin. Modify `vite.config.ts`. **Do NOT modify the entry file for twd-js init**. Entry file still needs the `twd-relay` browser-client connect block. |
| ❌ false | Keep current behavior — write the `if (import.meta.env.DEV) { initTWD(...) }` block in the entry file. |

## Step-by-step changes to `skills/setup/SKILL.md`

### Step 1: Auto-detection (extend)

Current: the skill reads `vite.config.ts` for `base` and `server.port`, but doesn't formally classify the project as Vite vs non-Vite.

**Add** a classification step that surfaces `isVite` to the user during the auto-detect summary:

> Here's what I detected:
> - Framework: React
> - **Build tool: Vite** ← new line
> - Vite base path: `/`
> - Dev server port: `5173`
> - Entry point: `src/main.tsx`
> - ...

If no Vite signal is found:

> - Build tool: **non-Vite** (Angular CLI / Webpack / unknown — will use manual setup) ← new line

### Step 4 sub-step 4: Configure entry point (REWRITE)

This is the major change. The current Step 4 sub-step 4 always inserts the manual block:

```typescript
// CURRENT — applies the same boilerplate to every project
if (import.meta.env.DEV) {
  const { initTWD } = await import('twd-js/bundled');
  const tests = import.meta.glob("./**/*.twd.test.ts");
  initTWD(tests, { open: true, position: 'left', serviceWorker: true, serviceWorkerUrl: '/mock-sw.js' });

  const { createBrowserClient } = await import('twd-relay/browser');
  const client = createBrowserClient({ url: `${window.location.origin}/__twd/ws` });
  client.connect();
}
```

Replace with branched logic.

#### Branch A — Vite project (preferred path)

The entry file gets ONLY the twd-relay browser client (no twd-js init). Put it in a guarded block so it doesn't ship in prod:

```typescript
// src/main.{ts,tsx} — Vite path
if (import.meta.env.DEV) {
  // twd-relay browser client (twd-js sidebar is auto-mounted by the twd() Vite plugin)
  const { createBrowserClient } = await import('twd-relay/browser');
  const client = createBrowserClient();
  client.connect();
}
```

Note: `createBrowserClient()` with no args auto-detects the URL when `twdRemote()` is registered as a Vite plugin. The skill should also confirm `twdRemote()` is in `vite.config.ts` (it's added in Step 4 sub-step 5, see below).

#### Branch B — non-Vite project (Angular CLI, Webpack/CRA, etc.)

Keep the current full block. Adjust import for non-Vite environments where `import.meta.env.DEV` may not exist:

```typescript
// src/main.{ts,tsx} — non-Vite path
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

For Angular specifically, also use `isDevMode()` from `@angular/core` instead of `import.meta.env.DEV`:

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

### Step 4 sub-step 5: Vite plugins (REWRITE for Vite projects)

Current sub-step 5 adds `twdHmr()` and `twdRemote()`:

```typescript
// CURRENT
import { twdHmr } from 'twd-js/vite-plugin';
import { twdRemote } from 'twd-relay/vite';

plugins: [
  // ... other plugins
  twdHmr(),
  twdRemote() as PluginOption,
]
```

Replace for **Vite projects** with the new `twd()` plugin (drop `twdHmr` since it's no longer needed):

```typescript
// NEW for Vite projects
import { twd } from 'twd-js/vite-plugin';
import { twdRemote } from 'twd-relay/vite';
import type { PluginOption } from 'vite';

plugins: [
  // ... other plugins (react(), tailwindcss(), istanbul(), etc.)
  twd({
    testFilePattern: '/**/*.twd.test.{ts,tsx}', // adjust to .ts only for Vue/Solid
    open: true,
    position: 'left',
    // Other options the user wants (search, theme, etc.) go here.
    // serviceWorker / serviceWorkerUrl defaults work; user overrides preserved.
  }),
  twdRemote() as PluginOption,
]
```

For **non-Vite projects**, skip this sub-step entirely (no Vite config to modify). Document that fact in the Step 4 narrative.

#### `testFilePattern` defaults by framework

| Detected framework | Recommended `testFilePattern` |
|---|---|
| React | `'/**/*.twd.test.{ts,tsx}'` |
| Vue | `'/**/*.twd.test.ts'` |
| Solid | `'/**/*.twd.test.{ts,tsx}'` |
| Other Vite-native | `'/**/*.twd.test.ts'` (default) |

#### Base path handling

The plugin auto-prefixes the script src and default `serviceWorkerUrl` based on the resolved Vite `base`. The skill no longer needs to manually adjust `serviceWorkerUrl` for non-root bases. It MAY still want to surface that the plugin handles this automatically, in the post-setup summary.

### Step 4 sub-step 6: Scaffold test file (NO CHANGE)

The scaffold test file (`src/twd-tests/hello.twd.test.ts`) is unchanged. The plugin's `testFilePattern` default matches it.

## `.claude/twd-patterns.md` changes

The generated `twd-patterns.md` template uses placeholders like `BASE_PATH` for `twd.visit` examples. **No changes needed here** — the plugin doesn't change the runtime API surface that tests use (`twd.visit`, `screenDom`, etc.). Only the SETUP code differs.

One small addition worth considering: a `## Vite Plugin` section that mirrors the plugin options the user picked, so future test-writing skills can reference what's configured. Optional, not blocking.

## Skill prompt changes — summary checklist

For the implementer (you) editing `skills/setup/SKILL.md`:

- [ ] Step 1: surface `isVite` in the auto-detect summary
- [ ] Step 2 batch 1: include "Build tool: Vite / non-Vite" in the confirmation summary
- [ ] Step 4 sub-step 4: branch the entry-file modification (Vite vs non-Vite vs Angular)
- [ ] Step 4 sub-step 5: rewrite the plugin block (drop `twdHmr`, add `twd()`); skip entirely for non-Vite
- [ ] Update `allowed-tools` if needed — current set covers it (no new tools required)
- [ ] Update the description at the top of `SKILL.md` to mention the plugin path

## Validation

After updating the skill, validate by running it on:

1. **A fresh React + Vite project** — confirm `twd()` ends up in `vite.config.ts`, `main.tsx` only gets the twd-relay block, no `initTWD` boilerplate is added.
2. **A fresh Vue + Vite project** — same as above with `testFilePattern: '/**/*.twd.test.ts'`.
3. **A non-Vite Angular project** — confirm the manual `initTWD` block lands in `main.ts` with `isDevMode()` guard, no Vite-config modification attempted.
4. **A project with `base: "/platform-admin/"`** — confirm the skill does NOT manually add `serviceWorkerUrl: '/platform-admin/mock-sw.js'`; the plugin handles it. (This is a regression check on the previous workaround.)

## Out of scope

These are deliberately not in this spec to keep the change focused:

- **`ci-setup` skill changes.** May also need updates if it references the entry-file boilerplate — separate audit.
- **`twd` skill changes.** The test-writing skill consumes `.claude/twd-patterns.md` and runtime APIs. Plugin adoption doesn't change either, so no edits needed.
- **Auto-install of `mock-sw.js`.** Still requires `npx twd-js init PUBLIC_DIR --save`. A future `twd-js` tier-1 follow-up will eliminate this; once that ships, this skill can drop the step.
- **`twd-relay` browser-client plugin.** A future `twd-relay` change could introduce a `twd-relay/vite-plugin` parallel to `twd()` that registers the browser client without entry-file changes. When/if that ships, both Vite-path entry blocks become empty and the entry file is fully untouched. Out of scope here.
- **Migration support for existing setups.** This spec covers fresh setups. Updating an existing project that has the old manual boilerplate to the new plugin is a separate workflow — could be a future `migrate` skill or documented manually.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| User has a Vite-based monorepo with multiple sub-apps and only one needs TWD | Skill already only writes to one entry/config pair at a time. Detection limited to project root. Document as out-of-scope. |
| User has a custom Vite plugin order requirement (e.g., `tailwindcss()` must be before `twd()`) | The skill's "add to plugins array" step preserves existing plugin order and inserts `twd()` at the end. Most projects don't care; document the position is editable. |
| User runs setup twice — old manual block in entry file AND new `twd()` plugin both registered | Detect existing `initTWD(` reference in entry file before modifying. If found, ask: "Existing manual TWD setup detected. Remove it and use the plugin instead?" |
| Detection fails on edge cases (e.g., Astro, which uses Vite under the hood but via `astro.config.mjs`) | Document Astro as a known case in the skill. For Astro, plugins go in `vite.plugins` block of `astro.config.mjs`. Worth a separate detection branch. |

## Reference: complete diff intent for the skill

For the skill maintainer, the structural change boils down to:

1. **Add a `isVite` boolean** to the detection state.
2. **Branch sub-step 4** of Step 4 on `isVite`.
3. **Branch sub-step 5** of Step 4 on `isVite` (skip entirely for non-Vite).
4. **Update the import in sub-step 5** from `twdHmr` to `twd`.
5. **Update the post-setup summary** to mention which approach was used.

Everything else in `SKILL.md` (auto-detection, the `.claude/twd-patterns.md` generation, the question batches, the scaffold test file) is unchanged.
