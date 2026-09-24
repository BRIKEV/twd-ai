---
name: ci-setup
description: Sets up CI for TWD tests — generates GitHub Actions workflow, installs twd-cli if missing, optionally configures code coverage, contract validation and PR video recording
disable-model-invocation: true
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash(npm install *)]
---

# TWD CI Setup

You are configuring CI/CD for TWD tests. Your job is to detect the project setup, ask whether coverage is needed, install packages, and generate a GitHub Actions workflow.

Read `skills/twd/references/ci.md` for twd-cli configuration, coverage setup, GitHub Actions templates, and the PR recording workflow.

## Step 1: Detect Project State

Read these files in parallel to understand the current setup:

1. **`package.json`** — detect:
   - Existing scripts (`dev`, `test:ci`, `dev:ci`, `collect:coverage:*`)
   - Installed packages (`twd-cli`, `vite-plugin-istanbul`, `nyc`, `vite`)
   - Dev server port from scripts if present
2. **`vite.config.ts`** (or `.js`, `.mjs`) — detect:
   - Whether Vite is in use (required for coverage)
   - Existing plugins (istanbul, twd)
   - `server.port` and `base` path
3. **`.claude/twd-patterns.md`** — detect:
   - Framework, port, base path from existing config
4. **`twd.config.json`** — check if it already exists
5. **Glob `.github/workflows/*.yml` AND `.github/workflows/*.yaml`** — check for existing workflows (GitHub Actions supports both extensions)
6. **Glob `contracts/**/*.json` AND `**/openapi*.{json,yaml}`** — check for OpenAPI specs (used in Step 2.5)
7. **Glob `.env`, `.env.example`, `.env.*`** and grep `src/` for `import.meta.env.VITE_[A-Z_]*` — collect the
   environment variables the app reads at runtime, and note which file reads each one (used in Step 2.7)
8. **`package.json` scripts, second pass** — look for a companion service the app needs before it can render:
   a `serve`, `serve:dev`, `mock*` or `api*` script, or anything invoking `json-server`. Note its port, and a
   health URL if one is obvious (used in Step 2.7)

## Step 2: Report Findings and Ask About Coverage

Report what you detected, then ask the user.

**If the user's request already specifies coverage** (e.g., "set up CI with istanbul coverage", "I want coverage"), skip the coverage question and proceed as if they said "Yes".

### If Vite is detected (and coverage not already specified):

> I detected [framework] with Vite on port [port].
>
> **Do you want to set up code coverage?**
> - **Yes** — installs `vite-plugin-istanbul` + `nyc`, adds coverage scripts, generates workflow with coverage steps
> - **No** — basic CI only (twd-cli + GitHub Actions)

### If Vite is NOT detected:

> I didn't detect a Vite configuration. Coverage requires Vite + vite-plugin-istanbul.
> I'll set up basic CI only (twd-cli + GitHub Actions).

### If an existing workflow is found:

> I found an existing workflow at `.github/workflows/[name].yml`.
> - **Overwrite** — replace it with the new TWD workflow
> - **New file** — create a separate `twd-tests.yml`
> - **Skip** — don't generate a workflow

## Step 2.5: Detect Contracts and Ask About Contract Validation

Use the OpenAPI specs found in Step 1 (item 6).

**If the user's request already mentions contracts** ("validate contracts", "use the OpenAPI spec", "we have contracts"), skip the question and proceed as if they said "Yes".

### If one or more OpenAPI specs were found:

> I found OpenAPI spec(s) at:
> - `contracts/<spec>.json`
>
> **Do you want to validate test mocks against them in CI?** This catches drift between your mocks and the real API on every PR.
> - **Yes** — adds `contracts[]` + `contractReportPath` to `twd.config.json`, sets `contract-report: 'true'` on the action, adds `pull-requests: write` permission, and appends `.twd` to `.gitignore`
> - **No** — skip; can be added later

### If no specs were found:

Skip this step silently.

### Sensible defaults when "Yes":

- **`baseUrl`** — default to `"/api"` if test files (`*.twd.test.ts` or `*.twd.test.tsx`) reference URLs starting with `/api/`. Grep `*.twd.test.*` for `url:\s*["']/api/` to confirm. Otherwise default to `"/"`.
- **`mode`** — `"error"` (strict by default; user can switch to `"warn"` later).
- **`strict`** — `true` (rejects unexpected properties).

The "Custom setup" workflow option (Step 7, Option B) does NOT support `contract-report` PR comments — only the GitHub Action handles that. If the user picks contracts AND custom setup, warn them that the contract report won't be posted as a PR comment and they'll need to read `.twd/contract-report.md` from build artifacts.

## Step 2.6: Ask About PR Video Recording

Only ask when **both** are true: existing TWD tests were found (Step 1, item 5)
and a GitHub Actions workflow is being generated. Otherwise skip this step
silently — there is nothing to record, or nowhere to run it.

**If the user's request already mentions recording** ("record the tests", "video
in the PR", "set up recording"), skip the question and proceed as if they said
"Yes".

> **Do you also want a PR video recording workflow?** Label a pull request
> `record` and it records the tests that branch added, then comments a link to
> one video per test.
> - **Yes** — adds a separate `.github/workflows/twd-record.yml`. Your test
>   workflow is untouched
> - **No** — skip; can be added later

### Why this is a separate workflow, not a flag on the test one

If the user asks to just add `--record` to the test workflow, push back once and
explain:

- A recording is optional and the pull request it describes is not. A
  label-triggered job runs after the work is already pushed, so it cannot cost
  the run that matters.
- Recording changes the conditions tests run under — its own viewport, the
  sidebar hidden, real delays between commands — so a recorded run can pass or
  fail differently. It is a demo artifact, not a gate.

If they still want it in the test workflow after that, do as they ask.

### Requirements to state when "Yes"

- **Pin the `record` action to a tag or commit SHA.** The action fetches its own pinned CLI, so nothing extra needs installing.
- **A Linux runner**, because the bundled ffmpeg build is Linux-only.
- **A `record` label** on the repository. The workflow does nothing until a label
  of that name exists and is applied, so tell the user to create it.

## Step 2.7: Confirm the Runtime Environment

Use the environment variables found in Step 1 (item 7) and the companion service
found in Step 1 (item 8).

Starting the dev server with neither is the most common way this skill produces a
green setup and a broken app. `wait-on` only proves that something answered on
the port — a module that threw at import time still serves a page. The failure
surfaces later, as a test that cannot find its elements, or as a recording of an
error screen.

### If environment variables were found:

> The app reads these at runtime:
> - `VITE_SUPABASE_URL` (from `.env.example`)
> - `VITE_API_BASE` (from `src/shared/api/client.ts`)
>
> CI needs a value for each, or the module that reads them throws on import.
> **What should CI use?**
> - **Placeholder (recommended)** — a literal dummy value written into the
>   workflow. TWD tests mock at the network layer, so the value is never dialled
> - **Repository secret** — `${{ secrets.NAME }}`, for a value a test genuinely
>   requests over the network

Default to placeholders, and reach for a secret only when the user says the value
is really used. A secret is not available to a pull request from a fork, so a
workflow that needs one cannot run there at all — and a label-triggered recording
workflow is a poor place to expose one.

Write a comment above the `env:` block saying why the placeholders exist. The
next person to read the workflow will otherwise take them for real credentials
and "fix" them.

### If a companion service was found:

> `package.json` has a `serve` script (json-server on port 3001). The app fetches
> on load, so the dev server needs it running first.
>
> I'll start it before Vite in every workflow I generate, each with its own
> `wait-on`.

### If neither was found:

Skip this step silently.

## Step 3: Install Packages

**Always ask before installing.** Show what will be installed and wait for confirmation.

### twd-cli (only if missing):

`/twd:setup` normally installs it. If `twd-cli` is not in `devDependencies`:

```
npm install --save-dev twd-cli
```

> This installs `twd-cli`, the headless runner the workflow calls. Proceed?

### If coverage was requested:

```
npm install --save-dev vite-plugin-istanbul nyc
```

> This installs `vite-plugin-istanbul` (code instrumentation) and `nyc` (coverage reporting). Proceed?

Run each install command only after the user confirms.

## Step 4: Update `twd.config.json`

`/twd:setup` creates this file with `url` and `coverage`. Read it, show it to the user, and merge only what CI needs — preserve `url` and every other key already there.

- **Coverage requested:** set `"coverage": true`.
- **Coverage not requested:** leave `coverage` as it is.
- **Contracts enabled (Step 2.5):** add `contractReportPath` and one `contracts[]` entry per detected spec, using the `baseUrl`, `mode` and `strict` defaults from Step 2.5.

Example after a merge with coverage and one spec at `contracts/todos-3.0.json`:

```json
{
  "url": "http://localhost:5173",
  "coverage": true,
  "contractReportPath": ".twd/contract-report.md",
  "contracts": [
    {
      "source": "./contracts/todos-3.0.json",
      "baseUrl": "/api",
      "mode": "error",
      "strict": true
    }
  ]
}
```

Do not add `timeout`, `headless`, `puppeteerArgs`, `coverageDir` or `nycOutputDir` — they are twd-cli defaults.

If the file does not exist (setup was skipped), create it with `url` from the detected port and base path, `coverage` per the user's choice, and the contract keys when enabled.

## Step 5: Configure Vite (Coverage Only)

Skip this step if coverage was not requested.

Add the istanbul plugin to `vite.config.ts`:

```typescript
import istanbul from "vite-plugin-istanbul";
```

Add to the `plugins` array:

```typescript
istanbul({
  include: "src/*",
  exclude: ["node_modules", "**/*.twd.test.ts"],
  requireEnv: !process.env.CI,
  extension: ['.ts', '.tsx'],
}),
```

**Rules:**
- Add the import at the top with other imports
- Add the plugin AFTER existing plugins (framework, twd)
- Do NOT remove or modify existing plugins
- Show the user the changes before applying

## Step 6: Add package.json Scripts

### `test:ci` (only if missing):

`/twd:setup` normally adds it. If absent:

```json
{
  "test:ci": "npx twd-cli run"
}
```

### If coverage was requested, also add:

```json
{
  "dev:ci": "CI=true vite",
  "collect:coverage:text": "npx nyc report --reporter=text --temp-dir .nyc_output",
  "collect:coverage:html": "npx nyc report --reporter=html --temp-dir .nyc_output",
  "collect:coverage:lcov": "npx nyc report --reporter=lcov --temp-dir .nyc_output"
}
```

**Rules:**
- Do NOT overwrite existing scripts without asking
- If `test:ci` or `dev:ci` already exist, show the conflict and ask the user
- Add scripts to the existing `"scripts"` object — do not replace it

## Step 7: Generate GitHub Actions Workflow

Ask the user which approach they prefer:

> **How do you want to run TWD tests in CI?**
> - **GitHub Action (recommended)** — uses the `BRIKEV/twd-cli` composite action, handles Puppeteer caching and Chrome installation automatically
> - **Custom setup** — full manual steps for complete control (or non-GitHub CI)

Create the `.github/workflows/` directory if it doesn't exist, then create `twd-tests.yml`.

### Option A: GitHub Action (Recommended)

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

If Step 2.7 turned up environment variables or a companion service, the dev
server step grows an `env:` block, and the service starts before it:

```yaml
      - name: Start mock API
        run: |
          nohup npm run serve > json-server.log 2>&1 &
          npx wait-on http://localhost:3001/api/health

      # Placeholders, not secrets: the suite mocks at the network layer, so these
      # are never dialled. They exist because the module that reads them throws
      # on construction when they are absent.
      - name: Start dev server
        run: |
          nohup npm run dev > /dev/null 2>&1 &
          npx wait-on http://localhost:5173
        env:
          VITE_SUPABASE_URL: http://localhost:54321
          VITE_SUPABASE_PUBLISHABLE_KEY: sb_publishable_ci_placeholder
```

Order matters, and each step gets its own `wait-on`. An app that fetches on load
will otherwise render its error state before the first test runs.

If coverage was requested, use `dev:ci` instead of `dev`, add `CI: true` env to the dev server step, and add the coverage step after the test step:

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

If contracts were enabled (Step 2.5), add the top-level `permissions` block and pass `contract-report: 'true'` to the action:

```yaml
permissions:
  pull-requests: write

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      # ... checkout, setup-node, install, msw init, start dev server ...

      - name: Run TWD tests
        uses: BRIKEV/twd-cli/.github/actions/run@main
        with:
          contract-report: 'true'
```

The `pull-requests: write` permission lets the action post the contract validation summary as a PR comment.

### Option B: Custom Setup

Use the appropriate template from `skills/twd/references/ci.md`:

- **Without coverage**: Use the "Basic Workflow" template
- **With coverage**: Use the "Workflow with Coverage" template

**Customize both options:**
- Set the correct port in the `wait-on` URL
- If base path is not `/`, append it to the `wait-on` URL
- Use `dev:ci` for the server command if coverage is enabled, `dev` otherwise

## Step 7.5: Generate the Recording Workflow (Recording Only)

Skip this step if recording was not enabled in Step 2.6.

Write the "Workflow template" from `skills/twd/references/ci.md` (the
**PR Recording** section) to `.github/workflows/twd-record.yml`. This is a new
file in every case — never merge recording into `twd-tests.yml`, for the reason
given in Step 2.6.

**Customize:**
- The port in the `wait-on` URL, and the base path if it is not `/`
- The dev script: `dev:ci` plus `CI: true` if coverage was enabled in Step 2, or
  plain `dev` — a recording does not need coverage instrumentation. This is the
  only step that may legitimately differ from the test workflow
- Drop the `npx twd-js init public --save` step if the project's public folder
  differs, matching whatever the test workflow uses

**Mirror the test workflow's environment exactly.** Whatever service steps and
`env:` blocks Step 7 wrote, this workflow gets the same ones — same order, same
values, same explaining comment. If the user kept an existing `twd-tests.yml`
instead of generating one, read that file and reproduce its service steps and
`env:` blocks here.

A recording runs the same app the tests run, and this is the job where a mismatch
is hardest to notice: its output is a video, and nobody reads the log of a job
that produced one. `wait-on` is satisfied by a served page, so a missing variable
never fails a step — it just makes every clip a recording of an error screen.

**Do not change:**
- `fetch-depth: 0` on the checkout — `changed-since` diffs against the base
  commit, and a depth-1 clone does not contain it
- `ref: github.event.pull_request.head.sha` — the merge commit is not the branch
  whose tests you want to see
- The pinned action ref. Pin to a tag or commit SHA, never `@main`: what a
  recording looks like is decided by the action and the CLI it invokes
- The `clip-count` zero check in the comment step. A branch that changed no tests
  has nothing to record, which is a success, not a failure
- `timeout-minutes`, `continue-on-error` on the comment steps, and
  `concurrency` — each one bounds a different way this can go wrong

## Step 8: Update `.gitignore` (Contracts Only)

Skip this step if contracts were not enabled.

The contract report is written to `.twd/contract-report.md`. Append `.twd` to `.gitignore` if it isn't already listed:

```
.twd
```

If `.gitignore` doesn't exist, create it with that single line. If it exists, read it first and only append when the entry is missing.

## Output

When done, summarize:

- What packages were installed
- What files were created or modified
- Whether coverage was set up
- Whether contract validation was set up (and which specs)
- Whether a PR recording workflow was created
- Which environment variables were wired into the workflows, and whether they are placeholders or secrets
- Next steps:
  - "Push to GitHub to trigger the workflow"
  - "Run `npm run test:ci` locally to verify headless tests work"
  - If coverage: "Run `npm run dev:ci` then `npm run test:ci` then `npm run collect:coverage:text` to see coverage locally"
  - If contracts: "Mock vs spec drift will appear as a PR comment after the next push; locally, check `.twd/contract-report.md` after `npm run test:ci`"
  - If recording: "Create a `record` label on the repo, then add it to a pull request to get one video per test the branch added"
  - If environment variables were wired in: "A new variable means editing **both** workflows — the test one and the recording one. They have to start the same app"
