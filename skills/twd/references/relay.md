# twd-relay — watch a run live (opt-in)

<!-- Package provenance: twd-relay (npm: brikev, MIT, github.com/BRIKEV/twd-relay).
     Network scope: localhost only, through the Vite dev server's WebSocket. Dev-only. -->

twd-cli is the default runner. Read this file only when the user asks to
**watch** tests run in their own browser tab. Relay is not faster for an agent
in any way that matters, and it needs a human to keep a tab open and in the
foreground. Never switch to it because twd-cli takes a few seconds to launch.

## Install

If twd-relay is missing, show the user these steps and ask before applying
them — the twd skill does not install packages beyond twd-js and twd-cli on
its own.

```bash
npm install --save-dev twd-relay
```

Vite projects add the plugin after `twd()`:

```typescript
import { twdRemote } from 'twd-relay/vite';
import type { PluginOption } from 'vite';

plugins: [
  // ... other plugins, then twd(...)
  twdRemote() as PluginOption,
]
```

`twdRemote()` auto-injects the browser client, so the entry file needs no relay
code. If an older setup left a manual `createBrowserClient(...).connect()` block
in the entry file, two clients connect and the relay logs a duplicate browser:
delete the block, or pass `autoConnect: false` to `twdRemote()` to keep it.

Non-Vite projects (Angular CLI, Webpack) have no plugin to serve `/__twd/ws` on
the app's own port, so the relay runs standalone and the client points at it
explicitly. Add the client inside the existing dev-only TWD block, after
`initTWD(...)`:

```typescript
const { createBrowserClient } = await import('twd-relay/browser');
createBrowserClient({ url: 'ws://localhost:9876/__twd/ws' }).connect();
```

Use that explicit URL, never `` `${window.location.origin}/__twd/ws` `` — the
app's origin does not serve the relay. Start the relay with
`npx twd-relay serve --port 9876` alongside the dev server.

## Pre-flight

This is the one place the skill may ask about a browser tab. Before a relay run:

1. The dev server is running.
2. The app is open in a browser tab. When connected, the tab title gains a
   `[TWD]` prefix and the favicon turns blue — that identifies it among other
   tabs to the same origin.
3. That tab stays in the foreground for the whole run. Chrome throttles timers
   in background tabs, which stretches tests 5–30×.

## Run

```bash
npx twd-relay run                                   # Vite defaults
npx twd-relay run --port 5173 --path "/BASE/__twd/ws"   # Vite under a non-root base
npx twd-relay run --port 9876                       # non-Vite: the standalone relay
npx twd-relay run --test "Login page"               # same describe-path matching as twd-cli
npx twd-relay run --max-test-duration 30000         # raise the abort threshold (0 disables)
```

On a non-Vite project pass `--port 9876` to `run` as well: `serve` defaults to
9876 but `run` defaults to 5173, and left mismatched it connects to nothing.

Exit code 0 = all passed, 1 = failures.

## Troubleshooting

| Error | Likely cause | Fix |
|-------|-------------|-----|
| `Run aborted: test "…" ran for Xs — threshold exceeded` | Either the tab was backgrounded and Chrome throttled it, **or** a failing assertion legitimately ran past the threshold — twd-js retries a failing assertion until its timeout before reporting it | Re-run the same `--test` under `npx twd-cli run`. If it fails there, read the real assertion error it prints. If it passes there, ask the user to foreground the `[TWD]` tab |
| `[RUN_IN_PROGRESS] A test run is already in progress…` | The previous run is still locked, usually because the tab was backgrounded and is finishing slowly | Ask the user to foreground or reload the `[TWD]` tab. The lock also auto-clears after 120 s of heartbeat silence. Restarting the relay does not help |
| Relay exits immediately or times out | Dev server not running, or no tab open | Check pre-flight items 1 and 2 |

Do not retry an aborted run in a loop. Without either a user action on the tab
or a switch to twd-cli, it aborts again.
