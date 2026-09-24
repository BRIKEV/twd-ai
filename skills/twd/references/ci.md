# TWD CI/CD Reference

<!-- Package provenance: twd-cli (npm: brikev, MIT, github.com/BRIKEV/twd-cli).
     vite-plugin-istanbul (npm: ifaxity, MIT). nyc (npm: istanbuljs, ISC).
     Istanbul instrumentation is guarded by requireEnv: !process.env.CI (only active in CI). -->

## twd-cli: Headless Test Runner

`twd-cli` is the same runner the agent uses locally. `/twd:setup` installs it,
creates `twd.config.json` and adds `"test:ci": "npx twd-cli run"`. CI setup only
installs it if missing and merges CI fields into the existing config.

### CI fields in `twd.config.json`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `url` | string | `"http://localhost:5173"` | Written by setup. Keep it; CI serves the app on the same URL |
| `coverage` | boolean | `true` | Setup writes `false`; set `true` when coverage is configured below |
| `coverageDir` | string | `"./coverage"` | Output folder for coverage reports |
| `nycOutputDir` | string | `"./.nyc_output"` | NYC temp folder |
| `contracts` | array | — | OpenAPI contract validation (see *Contract Validation*) |
| `contractReportPath` | string | — | Markdown contract report for the PR comment |

Only write keys that differ from these defaults.

### Run

```bash
npx twd-cli run
```

Exit code 0 = all passed, 1 = failures. `--test` takes the same describe-path
filter as locally; coverage is skipped on filtered runs.

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
    // ... other plugins (framework plugin, twd, etc.)
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

## Runtime Environment: env vars and companion services

Starting the dev server is enough only for an app that renders from static
imports. Two things commonly have to be in place first.

### Environment variables

Vite inlines `import.meta.env.VITE_*` at serve time. A module that reads one and
throws when it is absent — an API client asserting its base URL, an auth client
asserting its domain — takes the whole app down at import.

```yaml
      # Placeholders, not secrets: the suite mocks at the network layer, so these
      # are never dialled. They exist because src/shared/api/supabase.ts throws on
      # construction when they are absent.
      - name: Start Vite dev server
        run: |
          nohup npm run dev:ci > vite.log 2>&1 &
          npx wait-on http://localhost:5173
        env:
          CI: true
          VITE_SUPABASE_URL: http://localhost:54321
          VITE_SUPABASE_PUBLISHABLE_KEY: sb_publishable_ci_placeholder
```

Prefer a literal placeholder over `${{ secrets.NAME }}`. TWD tests mock at the
network layer, so the value is almost never dialled, and a secret is not
available to a pull request from a fork — a workflow that needs one simply cannot
run there. Use a secret only for a value a test genuinely requests over the
network.

Comment the block. Placeholders that look like credentials get "fixed" by the
next person to read the file.

### Companion services

An app that fetches on load needs its mock API running before Vite, each step
with its own `wait-on`:

```yaml
      - name: Start mock API
        run: |
          nohup npm run serve > json-server.log 2>&1 &
          npx wait-on http://localhost:3001/api/v1/health

      - name: Start Vite dev server
        run: |
          nohup npm run dev:ci > vite.log 2>&1 &
          npx wait-on http://localhost:5173
```

### Why this fails quietly

`wait-on` proves that something answered on the port. It does not prove the app
mounted. A missing variable or an absent API produces a served page showing an
error state, so every setup step goes green and the failure surfaces later — as a
test that cannot find its elements, or as a recording of an error screen with no
failed step anywhere in the log.

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

---

## PR Recording (Optional)

`twd-cli` can record a run to video, and the `record` composite action wraps the
whole thing — a known-good ffmpeg, the run, the artifact upload — into one step.
The payoff is a reviewer downloading one clip per test the branch added, straight
from the pull request.

Pin the `record` action to a tag or commit SHA; it fetches its own pinned CLI.

### When to enable

Offer it when the project already has TWD tests and runs on GitHub Actions. It is
optional and purely additive — nothing about the test workflow changes.

**Never add `--record` to the workflow that gates pull requests.** Keep recording
in a separate, label-triggered workflow:

- A recording is optional and the pull request it describes is not. A job that
  runs after the work is already pushed cannot cost the run that matters.
- Recording changes the conditions tests run under — its own viewport, the
  sidebar hidden, real delays inserted between commands — so a recorded run can
  pass or fail differently from a normal one. It is a demo artifact, not a gate.

### Workflow template

Write to `.github/workflows/twd-record.yml`. Substitute the project's detected
port in the `wait-on` URL, and `dev:ci` for `dev` if coverage is configured.

```yaml
name: Record a PR's tests

# Label a PR `record` and this records the tests the branch added, then comments
# the link. Deliberately separate from the test workflow: a recording is
# optional, the pull request it describes is not.
on:
  pull_request:
    types: [labeled]

concurrency:
  group: record-pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  record:
    if: github.event.label.name == 'record'
    runs-on: ubuntu-latest
    # Belt, not workaround: the CLI already guards against hangs, but a
    # recording must never cost a caller more than a recording.
    timeout-minutes: 15
    permissions:
      contents: read
      pull-requests: write # comment the link, drop the label
    env:
      GH_TOKEN: ${{ github.token }}

    steps:
      # The PR head, not the merge commit: the point is to see the tests this
      # branch built. fetch-depth: 0 because changed-since needs history, and a
      # depth-1 clone does not contain the base commit at all.
      - name: Checkout the PR head
        uses: actions/checkout@v5
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0

      - uses: actions/setup-node@v5
        with:
          node-version: 24
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Install mock service worker
        run: npx twd-js init public --save

      # The action assumes the app is already served at the url in
      # twd.config.json — the same contract the `run` action has.
      - name: Start dev server
        run: |
          nohup npm run dev > /dev/null 2>&1 &
          npx wait-on http://localhost:5173

      - name: Record the tests this branch added
        id: rec
        uses: BRIKEV/twd-cli/.github/actions/record@v1.8.0
        with:
          changed-since: ${{ github.event.pull_request.base.sha }}
          artifact-name: twd-recording-pr-${{ github.event.pull_request.number }}

      # Best effort: a fork PR gets a read-only token and cannot comment. Zero
      # clips is a normal outcome, not a failure.
      - name: Comment the link
        if: always()
        continue-on-error: true
        env:
          PR_NUMBER: ${{ github.event.pull_request.number }}
          CLIPS: ${{ steps.rec.outputs.clip-count }}
          VIDEO_URL: ${{ steps.rec.outputs.artifact-url }}
        run: |
          if [ "${CLIPS:-0}" = "0" ]; then
            gh pr comment "$PR_NUMBER" --body "Nothing to record: this branch added no TWD tests."
          else
            gh pr comment "$PR_NUMBER" --body "Recording: ${CLIPS} clip(s), one per test this branch added — [download the artifact](${VIDEO_URL}) and unzip."
          fi

      # Dropping the label makes a retry one click instead of remove-then-add.
      - name: Drop the label
        if: always()
        continue-on-error: true
        env:
          PR_NUMBER: ${{ github.event.pull_request.number }}
        run: gh pr edit "$PR_NUMBER" --remove-label record
```

### Environment parity with the test workflow

The template above starts a bare `npm run dev`. If the test workflow needs a
companion service or an `env:` block to make the app render — see
[Runtime Environment](#runtime-environment-env-vars-and-companion-services) —
this workflow needs the identical steps, in the same order, with the same values.

It is the general rule, in the place it bites hardest. The output of this job is
a video, so nobody reads its log; a missing variable does not fail a step, it
just makes every clip a recording of an error page.

The dev script is the one step that may legitimately differ: plain `dev` rather
than `dev:ci` is fine, because a recording does not need coverage
instrumentation.

Tell the user to create the `record` label on the repo — the workflow does
nothing until a label of that name exists and is applied.

### Action inputs

| Input | Default | Description |
|-------|---------|-------------|
| `working-directory` | `.` | Directory where `twd.config.json` lives |
| `cli-version` | `1.8.0` | `twd-cli` version to run, pinned by default |
| `changed-since` | (empty) | Record only the tests the branch added or changed since this ref. Needs `fetch-depth: 0`. Mutually exclusive with `tests` |
| `tests` | (empty) | Newline-separated test titles, each becoming one `--test` filter, OR'd. Mutually exclusive with `changed-since` |
| `pace` | (empty) | Milliseconds held after each command (`--record-pace`). Empty uses the CLI default of 300; `0` disables pacing |
| `install-ffmpeg` | `true` | Install a known-good ffmpeg 8.x. `false` uses whatever is on `PATH` |
| `upload-artifact` | `true` | Upload the clips as a workflow artifact |
| `artifact-name` | `twd-recording` | Name of the uploaded artifact |
| `retention-days` | `14` | How long to keep the artifact |

Outputs: `clip-count`, `dir`, `artifact-url`.

### Rules that are easy to get wrong

- **Pin the action to a tag or a commit SHA, never `@main`.** What a recording
  looks like is decided by the action and the CLI it invokes, so an unchanged
  repo should produce an unchanged video.
- **`clip-count: 0` is a success, not a failure.** A branch that changed no tests
  has nothing to record. Check the count before commenting, as the template does.
- **`changed-since` and `tests` are mutually exclusive.** Passing both fails the
  action with an explicit error rather than silently recording more than asked.
- **`install-ffmpeg` is Linux-only.** On any other runner it warns and skips, and
  installing ffmpeg 8+ becomes the caller's job. `mp4` needs 8 or newer because
  Puppeteer passes `-movflags hybrid_fragmented`; ubuntu-24.04's own package is
  6.1.1 and cannot record at all.
- **`pull-requests: write` is for the comment and the label only.** The action
  itself never touches the pull request.

Full documentation: https://twd.dev/recording#recording-in-ci
