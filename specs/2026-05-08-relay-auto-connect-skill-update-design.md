# Skill update — adopt `twd-relay` auto-connect (no manual `createBrowserClient` for Vite)

**Date:** 2026-05-08
**Repo:** `twd-ai`
**Skills affected:** `skills/setup/SKILL.md`, `skills/twd/references/setup.md`, `skills/twd/references/running-tests.md`
**Triggered by:** `twd-relay` shipping `autoConnect` (default `true`) on the `twdRemote()` Vite plugin (PR [BRIKEV/twd-relay#7](https://github.com/BRIKEV/twd-relay/pull/7))

## Motivation

`twd-relay`'s `twdRemote()` Vite plugin now auto-injects a `<script type="module">` into the dev-server `index.html` that imports `createBrowserClient` from `twd-relay/browser` and calls `.connect()`. Vite consumers no longer need a manual `createBrowserClient` block in their entry file.

The previous spec ([`2026-05-08-twd-vite-plugin-setup-skill-design.md`](./2026-05-08-twd-vite-plugin-setup-skill-design.md)) explicitly noted:

> Keeps the `twd-relay` browser-client init in the entry file in both cases (the relay does NOT have a plugin equivalent yet — that's a future twd-relay change, not in scope here).

That future change has now landed. After upgrading to the `twd-relay` version with auto-connect:

- **Vite projects** should drop the entry-file `createBrowserClient` snippet entirely. The plugin in `vite.config.ts` is the single point of relay configuration.
- **Non-Vite projects (Angular CLI, Webpack/CRA, Rollup, esbuild, Rspack)** continue to use the manual snippet — the manual API is unchanged and remains the supported public path for those bundlers.
- **Existing Vite consumers who upgrade and don't update their entry file** will end up with two clients connected (the plugin's auto-injected one *and* their manual one). This is loud — visible in relay logs as a duplicate browser — and the fix is one of: delete the manual block, or set `autoConnect: false` on the plugin.

The setup skill currently scaffolds the manual block on the Vite path. After this update it shouldn't, so users we onboard get the new clean default and don't immediately hit the double-client trap.

## What changed in `twd-relay` — quick recap

### Auto-connect on by default

```ts
// vite.config.ts
import { twdRemote } from 'twd-relay/vite';

export default defineConfig({
  plugins: [react(), twdRemote()],
});
```

That alone — no entry-file changes — gives you both the relay attached to the dev server *and* the browser client connected. The plugin runs only in dev (`apply: 'serve'`); production builds are untouched.

### Opt-out and forwarded options

```ts
twdRemote({ autoConnect: false })                         // wire createBrowserClient manually
twdRemote({ autoConnect: { reconnect: false, log: true } }) // forward client options to the injected call
```

The relay-server path and the injected client path use the same formula (`options.path ?? base + '/__twd/ws'`); `configResolved` sets the `base` for both, so they cannot drift.

### Migration matrix (for users we onboard / upgrade)

| Setup | Before | After upgrade |
|---|---|---|
| Vite plugin only (no manual block) | needed manual block in entry | works out of the box |
| Vite plugin + manual block | works (1 client) | **2 clients connect**; fix = remove block OR `autoConnect: false` |
| Non-Vite (Angular/Webpack/etc., manual API) | works | unchanged |

## Solution

Update the three skill files so they reflect the new default while keeping the manual API documented for non-Vite consumers and as a deliberate opt-out.

### Goal in one sentence

After this update, a fresh Vite project onboarded by the setup skill should have **zero** `createBrowserClient` references in its entry file; non-Vite projects should keep the existing manual snippet exactly as it is today.

## Skill changes

### 1. `skills/setup/SKILL.md` — Step 4, sub-step 4 ("Configure entry point")

**Branch A (Vite path) — currently scaffolds:**

```ts
if (import.meta.env.DEV) {
  // twd-relay browser client (twd-js sidebar is auto-mounted by the twd() Vite plugin)
  const { createBrowserClient } = await import('twd-relay/browser');
  const client = createBrowserClient();
  client.connect();
}
```

**Should become:** the entry file is left untouched on the Vite path. Both `twd()` (sidebar) and `twdRemote()` (relay + client) are plugins now; nothing dev-only is needed in `main.{ts,tsx}` at all.

Replace the entire Branch A code block with a short note:

> The `twd()` plugin auto-mounts the sidebar. The `twdRemote()` plugin (added in sub-step 5) auto-connects the browser client to the relay. **Do not add anything dev-only to `main.{ts,tsx}` on the Vite path** — both pieces are handled by the plugins. If you find an existing `if (import.meta.env.DEV) { ... initTWD(...) }` or `createBrowserClient(...)` block in the entry file from a previous setup, delete it.

The "Existing manual TWD setup detected" `AskUserQuestion` flow at line ~216 should also detect the standalone `createBrowserClient(...).connect()` block (without `initTWD`) and offer to remove it. One question covers both:

> Existing manual TWD setup detected in your entry file (`initTWD` and/or `createBrowserClient`). Remove it now and rely on the `twd()` + `twdRemote()` Vite plugins?

**Branch B (non-Vite path)** — unchanged. Continues to scaffold the full manual block including `createBrowserClient`. No edit needed there.

### 2. `skills/setup/SKILL.md` — Step 4, sub-step 5 ("Add Vite plugins")

The plugin-call snippet is correct as-is:

```ts
plugins: [
  twd({ /* ... */ }),
  twdRemote() as PluginOption,
]
```

But add one line to the explanatory paragraph immediately after it:

> `twdRemote()` defaults to `autoConnect: true`, so it injects a `<script>` tag that connects the browser client to the relay — no entry-file snippet needed. Pass `autoConnect: false` if you want to wire `createBrowserClient` manually (rare; only useful if you need to subscribe to client events).

### 3. `skills/twd/references/setup.md` — Step 3 ("Configure Entry Point")

This file currently has four framework-specific entry-file blocks (Bundled / Vue / Angular / Solid), all of which include the manual `createBrowserClient` snippet.

Rework Step 3 so it splits along Vite vs non-Vite, mirroring the setup SKILL:

- **Vite path (Bundled, Vue, Solid):** the entry file should not include any `createBrowserClient` snippet. If the framework still needs an `initTWD(...)` call (e.g., projects not using the `twd()` plugin), the relay piece is still skipped — a one-line note points the reader at sub-step 4 (Vite plugins) for both the sidebar and the relay client.
- **Angular (non-Vite):** keep the current manual block exactly. Angular CLI doesn't use Vite, so neither plugin applies; the manual snippet is the only path.

Concretely, the four blocks reduce to two:

  1. **Vite (Recommended — Bundled, Vue, Solid, anything Vite-based):**
     ```ts
     // src/main.{ts,tsx} — Vite path
     // No TWD-specific code needed in this file.
     // Both twd() and twdRemote() are configured in vite.config.ts.
     ```
     With a paragraph explaining: "The `twd()` plugin auto-mounts the sidebar (sub-step 5). The `twdRemote()` plugin auto-connects the relay browser client (sub-step 5). Both are dev-only via `apply: 'serve'`."
  2. **Angular (non-Vite):** keep the existing block verbatim, no changes.

Drop the standalone "Bundled Setup (Recommended — all frameworks)" header — the recommendation is now framework-aware. The "Vue" and "Solid.js" headers can be removed (they collapse into "Vite path"); their framework-specific lines (`createApp(App).mount('#app')` etc.) are not the skill's job to scaffold and were noise.

### 4. `skills/twd/references/setup.md` — Step 4 ("Vite Plugins")

Update the sample `vite.config.ts` snippet's commentary to mention auto-connect:

```ts
import { twdHmr } from 'twd-js/vite-plugin';
import { twdRemote } from 'twd-relay/vite';
import type { PluginOption } from 'vite';

export default defineConfig({
  plugins: [
    // ... other plugins
    twdHmr(),
    twdRemote() as PluginOption,
  ],
});
```

Append one sentence: "`twdRemote()` defaults to `autoConnect: true` and injects the relay browser client into `index.html` automatically. Use `twdRemote({ autoConnect: false })` if you need to wire `createBrowserClient` manually."

### 5. `skills/twd/references/running-tests.md` — pre-flight check item 5

Currently item 5 reads:

> 5. **Browser relay client is connected** — the entry point must include the `createBrowserClient` block (see setup reference Step 3)

This is now wrong for Vite projects. Replace with:

> 5. **Browser relay client is connected** — for Vite projects, this happens automatically when `twdRemote()` is in `vite.config.ts` (it injects a connect script via `transformIndexHtml`). For non-Vite projects (Angular, Webpack, etc.), the entry point must still include the manual `createBrowserClient` block (see setup reference Step 3, Angular path).

### 6. README and other touchpoints — out of scope here

`twd-ai/README.md` does not currently document the entry-file snippet directly; it relies on the skills. No README change needed in this spec.

`skills/ci-setup/SKILL.md` mentions `twdRemote` only in plugin-list contexts — no edit needed.

`skills/twd/SKILL.md:58` references checking for the `twdRemote()` plugin in `vite.config.ts` as part of an audit step. That stays accurate.

## Files changed

| File | Change |
|---|---|
| `skills/setup/SKILL.md` | Branch A entry-file block deleted (replaced by a short "no entry-file changes needed" note). The "existing manual TWD setup detected" question now also covers standalone `createBrowserClient` blocks. Sub-step 5 plugin paragraph mentions `autoConnect` default and opt-out. Branch B (non-Vite) unchanged. |
| `skills/twd/references/setup.md` | Step 3 collapsed from 4 framework blocks to 2 (Vite path with no entry-file code, Angular path with the manual block). Step 4 plugin commentary mentions `autoConnect`. |
| `skills/twd/references/running-tests.md` | Pre-flight item 5 split into Vite vs non-Vite cases. |

## Edge cases

| Scenario | Behavior |
|---|---|
| Setup skill runs on a fresh Vite project | Plugin in `vite.config.ts`, nothing in entry file. Single relay client connects. |
| Setup skill runs on a Vite project that already had the old manual block | Detection prompt offers removal; on confirm, the block is deleted. End state matches a fresh project. |
| Setup skill runs on Angular | Manual block scaffolded as today. No Vite plugin, no auto-connect. Unchanged. |
| User manually upgrades `twd-relay` without re-running setup, keeps the manual block | Two clients connect. Visible in relay logs. The `running-tests.md` pre-flight item now hints at this; the upstream `twd-relay` PR description and README also call it out. |
| User passes `twdRemote({ autoConnect: false })` and keeps the manual block | One client connects, behavior identical to pre-upgrade. Documented as the deliberate opt-out path. |
| Non-default Vite `base` (e.g. `/my-app/`) | `twdRemote()` resolves the base via `configResolved`; both the relay path and the injected client agree. The skill doesn't need to special-case base any more — drop any "adjust the relay client URL" notes from `references/setup.md` Step 3 if they remain on the Vite path. (Keep them on the non-Vite/Angular path where users still write the URL by hand.) |
| User has a project with both `initTWD(...)` AND `createBrowserClient(...)` from an even older skill version | The "Existing manual TWD setup detected" prompt covers both — one Y/N replaces both. |

## Testing approach

`twd-ai` skills are markdown — no unit tests. Verify by:

1. **Manual run-through** of `skills/setup/SKILL.md` against a fresh Vite + React project. After completion, grep the entry file: `grep -c createBrowserClient src/main.tsx` should be `0`.
2. **Manual run-through** against a fresh Angular project. After completion, the entry file should contain the manual `createBrowserClient(...).connect()` block exactly as before.
3. **Manual run-through** against a Vite project that already has the old manual block. The "existing setup detected" prompt should fire; after Y, the block should be gone.
4. **Reference cross-check:** open `references/setup.md` and `references/running-tests.md` and confirm the Vite path mentions zero `createBrowserClient` calls in entry files; the Angular/non-Vite path keeps them.

## Migration note (for already-onboarded users)

If a user we previously onboarded re-runs `/twd:setup` on the same project after upgrading `twd-relay`:

- The "Existing manual TWD setup detected" prompt should fire on their existing entry file's `createBrowserClient` block (sub-step 4 of the SKILL).
- On Y, the skill removes the manual block; on N, the skill leaves the entry alone but should print a one-line warning: "You've kept the manual `createBrowserClient` block. With `twd-relay`'s auto-connect plugin enabled, two browser clients will connect. Set `autoConnect: false` on `twdRemote()` if you want to keep the manual block."

The warning is the only place the double-client risk is surfaced inside the skill flow itself — the `running-tests.md` pre-flight is general guidance, not a per-run prompt.

## Non-goals

- Removing `createBrowserClient` from `twd-relay`. It stays public.
- Adding non-Vite plugin equivalents (Webpack, Angular, Rollup, Rspack). Manual API serves them.
- Changing the relay's CLI (`twd-relay run`) behavior, output, or pre-flight check semantics — only the documentation pointers in skill files change.
- Coordinating the auto-connect with React/Vue/Solid mount timing. Fire-and-forget is sufficient (the WS connect isn't on a mount-critical path); upstream spec confirmed this.
- Surfacing client events through plugin options. Users who need event hooks fall back to the manual API and `autoConnect: false` (already documented).
- Bumping the pinned `twd-relay` version anywhere — that's a separate change and lives in the consumer's `package.json`, not in the skill files.
