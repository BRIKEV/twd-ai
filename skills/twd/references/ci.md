# TWD CI/CD Reference

<!-- Package provenance: twd-cli (npm: brikev, MIT, github.com/BRIKEV/twd-cli).
     vite-plugin-istanbul (npm: ifaxity, MIT). nyc (npm: istanbuljs, ISC).
     Istanbul instrumentation is guarded by requireEnv: !process.env.CI (only active in CI). -->

## twd-cli: Headless Test Runner

`twd-cli` runs TWD tests in a headless browser — no open browser tab required.

### Install

```bash
npm install --save-dev twd-cli
```

### Configuration: `twd.config.json`

Create `twd.config.json` in the project root only if user confirms adding that file as this file is not required for twd-cli to work.

```json
{
  "url": "http://localhost:5173",
  "timeout": 10000,
  "coverage": true,
  "coverageDir": "./coverage",
  "nycOutputDir": "./.nyc_output",
  "headless": true,
  "puppeteerArgs": ["--no-sandbox", "--disable-setuid-sandbox"]
}
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `url` | string | `"http://localhost:5173"` | Dev server URL to open before running tests |
| `timeout` | number | `10000` | Milliseconds to wait for the page/sidebar |
| `coverage` | boolean | `true` | Toggle code coverage collection |
| `coverageDir` | string | `"./coverage"` | Output folder for coverage reports |
| `nycOutputDir` | string | `"./.nyc_output"` | NYC temp folder |
| `headless` | boolean | `true` | Run Chrome in headless mode |
| `puppeteerArgs` | string[] | `["--no-sandbox", "--disable-setuid-sandbox"]` | Extra arguments for Puppeteer |

> **Note**: If the project has a custom Vite base path or port, update the `url` accordingly.

### Run

```bash
npx twd-cli run
```

Exit code 0 = all passed, 1 = failures.

---

## Code Coverage with vite-plugin-istanbul + nyc

Code coverage instruments your source code so that when TWD tests run, coverage data is collected. This uses Istanbul via a Vite plugin (build-time instrumentation) and nyc (coverage reporting).

### Install Coverage Packages

```bash
npm install --save-dev vite-plugin-istanbul nyc
```

### Configure Vite Plugin

Add `istanbul()` to `vite.config.ts`:

```typescript
import istanbul from "vite-plugin-istanbul";

export default defineConfig({
  plugins: [
    // ... other plugins (framework plugin, twdHmr, twdRemote, etc.)
    istanbul({
      include: "src/*",
      exclude: ["node_modules", "**/*.twd.test.ts"],
      extension: ['.ts', '.tsx'],
      requireEnv: !process.env.CI,
    }),
  ],
});
```

**Options:**

| Field | Type | Description |
|-------|------|-------------|
| `include` | string \| string[] | Glob pattern(s) for files to instrument |
| `exclude` | string \| string[] | Glob pattern(s) for files to exclude |
| `extension` | string[] | File extensions to instrument (e.g. `['.ts', '.tsx']`) |
| `requireEnv` | boolean | If `true`, only instruments when `VITE_COVERAGE=true` is set. Use `!process.env.CI` to instrument only in CI. |

### Add package.json Scripts

```json
{
  "scripts": {
    "dev:ci": "CI=true vite",
    "test:ci": "npx twd-cli run",
    "collect:coverage:text": "npx nyc report --reporter=text --temp-dir .nyc_output",
    "collect:coverage:html": "npx nyc report --reporter=html --temp-dir .nyc_output",
    "collect:coverage:lcov": "npx nyc report --reporter=lcov --temp-dir .nyc_output"
  }
}
```

**Script purposes:**
- `dev:ci` — starts Vite with `CI=true` so istanbul instruments the code
- `test:ci` — runs TWD tests headlessly via twd-cli
- `collect:coverage:*` — generates coverage reports in different formats:
  - `text` — prints summary to terminal
  - `html` — generates browsable HTML report in `coverage/`
  - `lcov` — generates `lcov.info` for CI tools (Codecov, Coveralls, etc.)

### How Coverage Data Flows

1. `dev:ci` starts Vite → istanbul plugin instruments source files
2. `twd-cli run` launches headless browser → TWD tests execute against instrumented code
3. Coverage data is written to `.nyc_output/` automatically
4. `nyc report` reads `.nyc_output/` and generates reports

---

## GitHub Actions Workflows

### GitHub Action — Recommended

The `BRIKEV/twd-cli` composite action handles Puppeteer caching and Chrome installation automatically:

```yaml
name: TWD Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v5

      - uses: actions/setup-node@v5
        with:
          node-version: 24
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Install mock service worker
        run: npx twd-js init public --save

      - name: Start dev server
        run: |
          nohup npm run dev > /dev/null 2>&1 &
          npx wait-on http://localhost:5173

      - name: Run TWD tests
        uses: BRIKEV/twd-cli/.github/actions/run@main
```

With coverage, use `dev:ci` and add the coverage step:

```yaml
      - name: Start dev server
        run: |
          nohup npm run dev:ci > /dev/null 2>&1 &
          npx wait-on http://localhost:5173
        env:
          CI: true

      - name: Run TWD tests
        uses: BRIKEV/twd-cli/.github/actions/run@main

      - name: Display coverage
        run: npm run collect:coverage:text
```

### Custom Workflows (Full Control)

Use these if you need full control over each step or aren't using GitHub Actions.

### Basic Workflow (No Coverage)

```yaml
name: CI - twd tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Setup Node.js
        uses: actions/setup-node@v5
        with:
          node-version: 24
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install mock service worker
        run: npx twd-js init public --save

      - name: Start Vite dev server
        run: |
          nohup npm run dev > vite.log 2>&1 &
          npx wait-on http://localhost:5173

      - name: Cache Puppeteer browsers
        uses: actions/cache@v4
        with:
          path: ~/.cache/puppeteer
          key: ${{ runner.os }}-puppeteer-${{ hashFiles('package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-puppeteer-

      - name: Install Chrome for Puppeteer
        run: npx puppeteer browsers install chrome

      - name: Run TWD tests
        run: npx twd-cli run
```

### Workflow with Coverage

```yaml
name: CI - twd tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Setup Node.js
        uses: actions/setup-node@v5
        with:
          node-version: 24
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install mock service worker
        run: npx twd-js init public --save

      - name: Start Vite dev server
        run: |
          nohup npm run dev:ci > vite.log 2>&1 &
          npx wait-on http://localhost:5173

      - name: Cache Puppeteer browsers
        uses: actions/cache@v4
        with:
          path: ~/.cache/puppeteer
          key: ${{ runner.os }}-puppeteer-${{ hashFiles('package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-puppeteer-

      - name: Install Chrome for Puppeteer
        run: npx puppeteer browsers install chrome

      - name: Run TWD tests
        run: npx twd-cli run

      - name: Display coverage
        run: |
          npm run collect:coverage:text
```

### Customization Notes

- **Custom port**: Replace `5173` in `wait-on` URL with your project's port
- **Custom base path**: Append the base path to the `wait-on` URL (e.g., `http://localhost:5173/my-app/`)
- **Node version**: Adjust `node-version` to match your project
- **Package manager**: Replace `npm ci` / `npm run` with `yarn install --frozen-lockfile` / `yarn` or `pnpm install --frozen-lockfile` / `pnpm` if applicable
- **Coverage upload**: Add Codecov or Coveralls action after the coverage step if desired

---

## Contract Validation

`twd-cli` can validate test mocks against OpenAPI specs (3.0 or 3.1, JSON format) on every test run. When a mock response doesn't match the spec, the run fails with a diff showing the drift. This catches the case where the API changes but mocks don't.

### When to enable

Enable if the project ships an OpenAPI spec (commonly at `contracts/*.json` or `openapi.{json,yaml}`). Contract validation is the most impactful PR feedback `twd-cli` provides — opt in whenever a spec exists.

### `twd.config.json` fields

```json
{
  "contractReportPath": ".twd/contract-report.md",
  "contracts": [
    {
      "source": "./contracts/<spec>.json",
      "baseUrl": "/api",
      "mode": "error",
      "strict": true
    }
  ]
}
```

**Contract options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `source` | string | — | Path to the OpenAPI spec file (JSON) |
| `baseUrl` | string | `"/"` | Base URL prefix stripped when matching mock URLs to spec paths |
| `mode` | `"error"` \| `"warn"` | `"warn"` | `error` fails the run, `warn` reports only |
| `strict` | boolean | `false` | When `true`, unexpected properties are rejected |
| `contractReportPath` | string | — | Path (relative to project root) for the markdown report posted as a PR comment |

### Workflow additions

Top-level `permissions` block (needed so the action can post the PR comment):

```yaml
permissions:
  pull-requests: write
```

And enable the report on the action:

```yaml
- name: Run TWD tests
  uses: BRIKEV/twd-cli/.github/actions/run@main
  with:
    contract-report: 'true'
```

The composite action reads `contractReportPath` from `twd.config.json` and posts the contents as a PR comment when `contract-report: 'true'`.

### `.gitignore`

The report directory is generated output:

```
.twd
```

### Custom (non-action) workflows

The `contract-report: 'true'` input is specific to the `BRIKEV/twd-cli/.github/actions/run` composite action. With a custom workflow, `twd-cli run` will still validate contracts and write `.twd/contract-report.md` (if `contractReportPath` is set), but you'll need to upload it as a build artifact or post the comment yourself — there's no built-in PR comment posting outside the action.
