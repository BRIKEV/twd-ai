# TWD Plugin for Claude Code

Deterministic in-browser testing plugin for Claude Code. Writes, runs, and fixes component-level browser tests for SPAs using [TWD (Test While Developing)](https://github.com/BRIKEV/twd).

TWD tests run inside the app's own dev server — your real app and component tree, with APIs mocked by a service worker. The agent runs them headlessly with `twd-cli`, so nothing needs a human watching a tab. This makes TWD **complementary to E2E tools like Playwright or Cypress**, not a replacement: use TWD for fast, deterministic component and page-level tests during development; use Playwright/Cypress for full end-to-end flows across real network requests and browsers.

## Installation

Add the marketplace and install the plugin:

```bash
claude plugin marketplace add BRIKEV/twd-ai
claude plugin install twd@twd-ai
```

## What's Included

### `/twd:setup` Command

Interactive setup that detects your project configuration and generates `.claude/twd-patterns.md` — a project-specific config file the TWD agent reads for every test run.

```
/twd:setup
```

What it does:
- Auto-detects framework, Vite config, entry point, CSS libraries
- Asks about auth middleware, third-party modules, API folder structure
- Generates `.claude/twd-patterns.md` with project-specific patterns
- Installs `twd-js` and `twd-cli`, writes `twd.config.json` and a `test:ci` script
- Adds `twd-lint`: as an ESLint plugin when the project has an ESLint flat config, otherwise as a `lint:twd` script
- Wires the `twd()` Vite plugin (or a dev-only `initTWD` block for non-Vite projects)
- Runs the suite once against your dev server to confirm the wiring

### `/twd:ci-setup` Command

Sets up CI/CD for TWD tests — installs `twd-cli`, optionally configures code coverage, and generates a GitHub Actions workflow.

```
/twd:ci-setup
```

What it does:
- Detects your project setup (framework, Vite config, existing workflows)
- Installs `twd-cli` if setup has not already
- Optionally sets up code coverage with `vite-plugin-istanbul` + `nyc` (requires Vite)
- On Vite, starts the CI dev server in production mode (`dev:ci`), which roughly halves the run. Coverage stays on there, and `vite build` stays uninstrumented
- Generates `.github/workflows/twd-tests.yml`, which lints the TWD tests before any server starts
- Optionally generates `.github/workflows/twd-record.yml` — label a PR `record` and get one video per test the branch added
- Wires the environment variables and mock-API steps the app needs into **both** workflows — a recording has to start the same app the tests do

### `twd` Skill

Autonomous testing agent that writes, runs, and fixes in-browser tests. Invoked by the model when you ask for testing work.

Examples:
- "Write tests for the login page"
- "Run all TWD tests and fix any failures"
- "Set up TWD and test the dashboard"

The agent follows a 5-phase workflow:
1. **Detect** — checks project state and reads `.claude/twd-patterns.md`
2. **Setup** — installs TWD if needed (packages, service worker, entry point)
3. **Write** — analyzes your app and writes flow-based tests, plus Testing Library `render()` component tests when a component itself is the subject, then type-checks and lints them (`npx twd-lint --fix`) before the first browser run
4. **Run & Fix** — probes the dev server, runs tests headlessly via twd-cli, isolates failures with `--test`, fixes them, closes with a full-suite run
5. **Report** — summarizes coverage and results

## Tested Scenarios

The skills are checked with [plugin evals](https://code.claude.com/docs/en/plugin-evals): each scenario scaffolds a small project, runs the skill without a human in the loop, and grades the files it writes. A scenario listed here is one a skill change cannot quietly break.

| Scenario | Skill | Verified |
|---|---|---|
| Vite + React app with TanStack Query and ESLint | `/twd:setup` | `twd()` Vite plugin, `twd.config.json`, `test:ci`, twd-lint in the ESLint config, query cache reset in `twd-patterns.md` |
| App with a mock API and a required env var | `/twd:ci-setup` | Test workflow on the `twd-cli` action, a separate label-triggered recording workflow, both starting the same app |
| Page flow tests | `twd` | Runner imports, mocks before visit, every async call awaited, payload asserted on the request, type-checked and linted |
| Component test with Testing Library | `twd` | Rendered into an isolated host, cleaned up between tests, network mocked rather than project code stubbed |
| A page around a third-party component (camera scanner) | `twd` | The component replaced with `twd.mockComponent()`, its callbacks driven by the fake, the page's own code untouched |
| A failing suite to get green | `twd` | A filtered `--test` run before the full one, `run.json` read, the test fixed rather than the app |
| Fixing a hand-written test | `twd` | twd-lint run and every report fixed |
| A unit-test request in a project with TWD | `twd` | The skill stays out of it: unit tests are left to the project's own runner |

Scenarios outside this table may still work; they are not guarded yet. See [`evals/README.md`](evals/README.md) for the exact checks and how to run them.

## Packages Used

| Package | Purpose | Scope |
|---------|---------|-------|
| `twd-js` | Core testing library | devDependency |
| `twd-cli` | Headless test runner — the agent loop and CI | devDependency |
| `twd-lint` | Lints TWD tests: missing `await`, wrong runner imports, `rule.request.body`, `it.only` | devDependency (optional) |
| `twd-relay` | Watch a run live in your own tab | devDependency (optional) |
| `vite-plugin-istanbul` | Code coverage instrumentation | devDependency (optional) |
| `nyc` | Coverage reporting (text, html, lcov) | devDependency (optional) |

All packages are published by [BRIKEV](https://www.npmjs.com/~brikev) under MIT license. TWD code is guarded by `import.meta.env.DEV` — never included in production builds. `twd-cli` and `twd-relay` operate exclusively on localhost.

## Project Config: `.claude/twd-patterns.md`

Generated by `/twd:setup`, this file contains:
- Framework and Vite configuration
- Runner commands, app URL, dev command, default branch and type-check command
- Standard imports and beforeEach template
- Visit path prefixes
- API service folder location
- Auth middleware and permission mapping
- Third-party modules (what to Sinon-stub in tests)
- CSS/component library references

The `twd` agent reads this file at the start of every run to use project-specific values.

## Updating the Plugin

First refresh the marketplace, then update the plugin:

```bash
claude plugin marketplace update twd-ai
claude plugin update twd@twd-ai
```

Restart Claude Code to apply changes.

## License

MIT
