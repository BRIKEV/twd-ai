# TWD Test Running Reference

<!-- Network scope: twd-relay operates exclusively on localhost via the local Vite dev server WebSocket.
     No external network connections are made. Dev-only dependency (--save-dev). -->

## Running Tests via twd-relay

`twd-relay` always runs ALL test files. There is no single-file execution flag.

```bash
# Default (Vite default port 5173, base path /)
npx twd-relay run

# Custom port and/or base path
npx twd-relay run --port 5173 --path "/my-app/__twd/ws"
```

`--port` and `--path` are optional — omit them if the project uses Vite defaults.

Exit code 0 = all passed, 1 = failures.

## Running Specific Tests

Use `--test` to isolate tests by name (substring match, case-insensitive):

```bash
# Run tests matching "should show error"
npx twd-relay run --test "should show error"

# Run multiple specific tests (OR logic — matches any)
npx twd-relay run --test "login" --test "signup"
```

When no tests match the filter, the CLI prints the available test names so you can correct the filter.

## Running Tests Headlessly (CI)

For CI/headless execution without a browser open:

```bash
npx twd-cli run
```

This launches a headless browser, runs all tests, and reports results. Configure via `twd.config.json` in the project root.

## MANDATORY Pre-Flight Check — DO NOT SKIP

**Tests WILL fail silently or hang if these conditions are not met.**

Before running `npx twd-relay run`, **ALL** of the following must be true:

1. **The dev server MUST be running** — run `npm run dev` (or your project's dev command) in a separate terminal. The relay connects to the Vite dev server via WebSocket — without it, the relay has nothing to connect to.
2. **The app MUST be open in a browser tab** — navigate to `http://localhost:PORT` (e.g., `http://localhost:5173`). TWD tests execute inside the browser — if no tab is open, the relay cannot dispatch tests.
3. **`twd-relay` is installed** — `npm install --save-dev twd-relay`
4. **`twdRemote()` plugin is in `vite.config.ts`** — see setup reference
5. **Browser relay client is connected** — the entry point must include the `createBrowserClient` block (see setup reference Step 3)

> **If the relay exits immediately or times out**, the #1 cause is that the dev server is not running or the browser tab is not open. Always check these first.

## Reading Failures

When tests fail, the output includes:
- **Test name** — which `describe` > `it` block failed
- **Error message** — what assertion failed or what error was thrown
- **Expected vs Actual** — for assertion mismatches

## Common Failures and Fixes

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| "Unable to find role X" | Element doesn't exist or has wrong role | Check component markup, use correct role/name |
| "Unable to find an element with the text" | Text doesn't match or element hasn't rendered | Use regex (`/text/i`), or switch to `findByText` for async |
| "Expected X to equal Y" | Mock data doesn't match expected shape | Update mock data or expected value |
| "Timed out waiting for element" | Element loads async, using `getBy` instead of `findBy` | Switch to `await screenDom.findByRole(...)` |
| "Request not intercepted" | Mock URL doesn't match actual request | Use `twd.getRequestCounts()` to check if the mock was hit at all. If count is 0, the URL or method isn't matching. Verify the string URL matches (boundary-aware). For dynamic IDs, hardcode the mock value. Only use `urlRegex: true` as last resort |
| "Cannot read property of null" | Missing `await` on async method | Add `await` before `twd.get()`, `userEvent.*`, etc. |
| "twd.mockRequest is not a function" | Service worker not initialized | Ensure `serviceWorker: true` in `initTWD` options |
| Assertion fails intermittently (element found but wrong attribute/text/state) | Race condition — render hasn't completed yet | Wrap in `await twd.waitFor(() => ...)` with the failing assertion or selector. See `test-writing.md` "waitFor vs twd.wait" for guidance |
| `Run aborted: test "…" ran for Xs — threshold exceeded` | Browser tab is backgrounded/minimized → Chrome is throttling timers → tests run 5–30× slower than normal | Foreground the TWD tab (identified by the `[TWD …]` title prefix) and rerun. For unattended runs, switch to `npx twd-cli run` which uses a headless browser not subject to tab throttling. Raise the threshold with `npx twd-relay run --max-test-duration 15000` if a test legitimately needs longer. |
| `[RUN_IN_PROGRESS] A test run is already in progress…` | Previous run still locked on the relay. Usually the TWD tab was backgrounded during the prior run and is still slowly completing it. | Foreground the TWD tab (identified by the `[TWD …]` title prefix) to speed completion. The relay auto-clears the lock after 120 s of heartbeat silence, or reload the TWD tab to force-reset. Don't kill/restart the relay — it won't help. |

## Recovery from Aborted or Stuck Runs

Chrome throttles timers in backgrounded tabs, which can stretch a ~1 s test run to 20+ seconds. To avoid hangs, the browser client aborts any run where a single test exceeds **5 seconds** by default (configurable via `--max-test-duration <ms>`). When this fires, the CLI prints `Run aborted: …` and exits 1.

**When you see `run:aborted` or a stuck `RUN_IN_PROGRESS`:**

- Tell the user to foreground the TWD browser tab. The tab's title is prefixed with `[TWD]` when the relay is connected, which helps them identify it among other tabs to the same origin.
- If the user needs unattended/CI execution, recommend `npx twd-cli run` — it uses a headless Chrome where tab throttling doesn't apply.
- Don't retry in a loop. The root cause is the tab losing focus; a retry without user action will abort again.
- Don't kill/restart the relay. The lock auto-clears after 120 s of heartbeat silence, or the user can reload the tab.

## Debugging Tips

- Use `npx twd-relay run --test "test name"` to isolate a single test
- Add `await twd.wait(2000)` to pause and visually inspect the page
- If a test fails intermittently due to timing, use `await twd.waitFor(() => ...)` to retry until the condition is met — don't replace it with a blind `twd.wait(ms)`
- Check the browser console for JavaScript errors
- Verify mock URLs match by reading the API/service layer code
- **When `waitForRequest` times out**, use `twd.getRequestCounts()` to diagnose:
  - Count is 0 → the mock URL or method isn't matching the actual request
  - Count is > 0 → the mock matched but `waitForRequest` was called before/after the request fired
  - `twd.getRequestCount("alias")` checks a single mock; `twd.getRequestCounts()` returns all as `{ alias: count, ... }`
