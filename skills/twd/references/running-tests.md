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

**The ONLY way to isolate a single test is `it.only()` in the test file.** The relay will still load all files, but only the `it.only()` test will execute.

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
| "Request not intercepted" | Mock URL doesn't match actual request | Verify the string URL matches (matching is boundary-aware). For dynamic IDs, hardcode the mock value. Only use `urlRegex: true` as last resort |
| "Cannot read property of null" | Missing `await` on async method | Add `await` before `twd.get()`, `userEvent.*`, etc. |
| "twd.mockRequest is not a function" | Service worker not initialized | Ensure `serviceWorker: true` in `initTWD` options |

## Debugging Tips

- Use `it.only("test name", ...)` to isolate a single test
- Add `await twd.wait(2000)` to pause and visually inspect the page
- Check the browser console for JavaScript errors
- Verify mock URLs match by reading the API/service layer code
