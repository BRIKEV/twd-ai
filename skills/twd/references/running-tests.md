# TWD Test Running Reference

<!-- Network scope: twd-cli launches a local headless Chrome (Puppeteer) against the local dev server.
     No external network connections. Dev-only dependency (--save-dev). -->

twd-cli launches its own headless browser against the running dev server. Only
the dev server has to be up — no tab, no focus, nothing for the user to watch.
To watch a run live instead, see `relay.md`; do not reach for it otherwise.

## Resolving the URL

`url` in `twd.config.json`, otherwise `http://localhost:5173` plus the base
path from `.claude/twd-patterns.md`. twd-cli reads the same file, so the probe
and the run always target the same server. If the app moved to another port,
fix `url` in `twd.config.json`.

## The probe

One tool call, reachability only:

```bash
curl -s --max-time 3 -o /dev/null -w '%{http_code}' <url>
```

- **Any HTTP status** (200, 302, even 404) means the server is up. Proceed.
- **`000`** means nothing answered. Tell the user the dev command from
  `twd-patterns.md` (for example `npm run serve:dev`) and the URL, then stop.
  Ask once. Do not poll.

Never ask about a browser tab or whether TWD is enabled — if TWD is not
active, twd-cli says so and names the fix (see *Diagnostics*).

## Cadence

```bash
# First run after writing a file — the describe name runs the whole file
npx twd-cli run --test "Todo list"

# Isolating a failure (repeatable, OR'd)
npx twd-cli run --test "should create a todo" --test "should show the error"

# Everything this branch added or changed
npx twd-cli run --changed-since origin/<default>

# Closing run — unfiltered
npx twd-cli run
```

`<default>` is the default branch from `twd-patterns.md`, or
`git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`), falling
back to `main`. If `--changed-since` fails for any git reason — no remote, ref
not in the clone, not a git repository — skip the branch check and say so in
the report.

The closing run always happens unless `twd-patterns.md` says `Closing run: CI`.
Never pass a filtered or `--changed-since` run off as the full suite.

A `--test` filter that matches nothing exits 1 with `No tests matched
filter(s): …` — grep the test files for the exact describe or it title.
`npx twd-cli run --help` lists every flag.

## Reading the output

Every run ends with one block. It is the whole answer — never pipe through
`tee`, `head` or `tail`, never grep for `✓`, never count lines.

```
--- Run complete ---
  Passed: 41 | Failed: 1 | Skipped: 0
  Duration: 38.2s

  Failed tests (1):
    × Todo list > should create a todo
      mock rules  2/3 triggered — createTodo never requested
      AssertionError: expected 3 rows to have length 4

  Retried (1):
    ✓ Todo list > should filter completed (passed on attempt 2)
```

- **`Failed tests (n)`** — the failures, each with its describe-path, the
  `mock rules` row when the test registered mocks, and the error.
- **`Retried (n)`** — passed only on a later attempt. Each one is a finding.
  If you wrote or touched the test, fix it like a failure: usually a missing
  `await twd.waitFor(...)`, state not reset in `beforeEach`, or a mock
  registered after `visit`. Otherwise list it in the report with its attempt
  number. A green run with retries is not a clean run.
- **`Mocks validated: … | Errors: n`** and lines like
  `✗ GET /api/todos (200) — mock "todos"` are contract validation, not test
  failures.
- **`⚠ Stopped early: reached the failure limit`** — the run stopped after the
  listed failures; fix them before looking for more.

## The `mock rules` diagnostic

A failing test that registered mock rules gets a row above its error:

```
    mock rules  6/7 triggered — catalog never requested
```

Of 7 registered rules, 6 were requested by the app and `catalog` never was. A
rule that never fires usually means its URL or method does not match what the
app requests — a faster lead than the assertion, because it names the mock.
With several misses it expands, capped at five. The row is absent when the test
registered no rules.

**Do not trust that row on a full-suite run.** It reads the global rule
registry, which nothing resets between tests unless the project clears it, so
rules from earlier tests are counted and blamed on this one.

1. Re-run the one test alone with `npx twd-cli run --test "the failing test"`.
   In isolation the row is accurate.
2. If the aliases change or disappear, it was bleed. Debug the assertion.
3. The durable fix is in the test setup. `afterEach` comes from `twd-js/runner`
   and must sit inside a `describe()`:

   ```ts
   import { describe, it, afterEach } from "twd-js/runner";
   import { twd } from "twd-js";

   describe("Inquiries", () => {
     afterEach(() => {
       twd.clearRequestMockRules();
     });
     // ...
   });
   ```

## Seeing a test

```bash
npx twd-cli run --record --test "<exact it() title>"
```

Writes one clip per matched test to `twd-artifacts/`. Needs ffmpeg on the PATH;
twd-cli checks the binary before launching anything and says what is missing.
This is how a human reviews what you built. Offer it in the report; do not run
it unasked.

## Diagnostics

| Output | Likely cause | Fix |
|---|---|---|
| `Could not reach <url> (ERR_CONNECTION_REFUSED)` | Dev server not running, or the wrong URL | Tell the user the dev command. If the app is on another port or path, fix `url` in `twd.config.json` |
| `Page loaded but the TWD sidebar (#twd-sidebar-root) did not appear` | `twd()` plugin missing from the Vite config, or gated behind an env flag the dev command did not set | Check `vite.config.*` and the dev command in `twd-patterns.md` |
| `No tests matched filter(s)` | Typo in `--test`, or the file is not discovered | Grep the test files for the exact title. For a new `.tsx` file check `testFilePattern` |
| `A single chunk of tests exceeded Puppeteer's protocolTimeout` | One hanging test | Isolate with `--test`; look for an un-awaited promise or an element that never appears |
| A failing test takes ~12 s | twd-js retries a failing assertion until its timeout, then reports it | Read the error. A value that will never change on retry is a wrong expectation, not a timing problem |
| `--changed-since <ref>: <ref> is not in this clone` | No remote, shallow clone, base branch not fetched, or any other git error | Skip the branch check locally; in CI set `fetch-depth: 0` |
| `Unable to find role X` | Element missing or has a different role | Check the component markup; use the correct role/name |
| `Unable to find an element with the text` | Text differs or has not rendered yet | Use a regex (`/text/i`) or `findByText` for async content |
| `Expected X to equal Y` | Mock data does not match the expected shape | Update the mock data or the expected value |
| `Timed out waiting for element` | Async element queried with `getBy` | Use `await screenDom.findByRole(...)` |
| `Rule "alias" was not executed` | Mock URL or method does not match the real request, or `waitForRequest` ran before/after it fired | `twd.getRequestCounts()`: 0 means the mock never matched, > 0 means a timing problem. Verify the string URL (boundary-aware). Hardcode dynamic IDs. `urlRegex: true` only as a last resort |
| `Cannot read property of null` | Missing `await` | Add `await` before `twd.get()`, `userEvent.*`, etc. |
| `twd.mockRequest is not a function` | Service worker not initialized | Check `public/mock-sw.js` exists and `serviceWorker` is not disabled |
| Assertion fails intermittently, or shows under `Retried` | Render not finished when asserted | Wrap the check in `await twd.waitFor(() => ...)`. Not preemptively — only for a test that failed on timing. See `test-writing.md` "waitFor vs twd.wait" |
| `mock rules 0/N triggered` on a test that registers no mocks | Rule bleed from earlier tests | See *The `mock rules` diagnostic* |
