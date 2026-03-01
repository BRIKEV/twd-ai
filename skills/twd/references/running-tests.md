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

## Prerequisites

Before running tests, ensure:
1. The dev server is running (`npm run dev`)
2. `twd-relay` is installed (`npm install --save-dev twd-relay`)
3. `twdRemote()` plugin is in `vite.config.ts`
4. Browser client is connected (see setup reference)

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
| "Request not intercepted" | Mock URL doesn't match actual request | Check the URL pattern, enable `urlRegex` if needed |
| "Cannot read property of null" | Missing `await` on async method | Add `await` before `twd.get()`, `userEvent.*`, etc. |
| "twd.mockRequest is not a function" | Service worker not initialized | Ensure `serviceWorker: true` in `initTWD` options |

## Debugging Tips

- Use `it.only("test name", ...)` to isolate a single test
- Add `await twd.wait(2000)` to pause and visually inspect the page
- Check the browser console for JavaScript errors
- Verify mock URLs match by reading the API/service layer code
