---
name: ci-setup
description: Sets up CI for TWD tests — generates GitHub Actions workflow, installs twd-cli, optionally configures code coverage
disable-model-invocation: true
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash(npm install *)]
---

# TWD CI Setup

You are configuring CI/CD for TWD tests. Your job is to detect the project setup, ask whether coverage is needed, install packages, and generate a GitHub Actions workflow.

Read `skills/twd/references/ci.md` for twd-cli configuration, coverage setup, and GitHub Actions templates.

## Step 1: Detect Project State

Read these files in parallel to understand the current setup:

1. **`package.json`** — detect:
   - Existing scripts (`dev`, `test:ci`, `dev:ci`, `collect:coverage:*`)
   - Installed packages (`twd-cli`, `vite-plugin-istanbul`, `nyc`, `vite`)
   - Dev server port from scripts if present
2. **`vite.config.ts`** (or `.js`, `.mjs`) — detect:
   - Whether Vite is in use (required for coverage)
   - Existing plugins (istanbul, twdHmr, twdRemote)
   - `server.port` and `base` path
3. **`.claude/twd-patterns.md`** — detect:
   - Framework, port, base path from existing config
4. **`twd.config.json`** — check if it already exists
5. **Glob `.github/workflows/*.yml` AND `.github/workflows/*.yaml`** — check for existing workflows (GitHub Actions supports both extensions)

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

## Step 3: Install Packages

**Always ask before installing.** Show what will be installed and wait for confirmation.

### Always install:

```
npm install --save-dev twd-cli
```

> This installs `twd-cli` for headless test running in CI. Proceed?

### If coverage was requested:

```
npm install --save-dev vite-plugin-istanbul nyc
```

> This installs `vite-plugin-istanbul` (code instrumentation) and `nyc` (coverage reporting). Proceed?

Run each install command only after the user confirms.

## Step 4: Create `twd.config.json`

If `twd.config.json` does not already exist, create it in the project root only if user confirms adding that file as this file is not required for twd-cli to work.

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

Use the detected port in the `url` field (default `5173`). If coverage was not requested, set `"coverage": false`.

If `twd.config.json` already exists, show its contents and ask if the user wants to update it.

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
- Add the plugin AFTER existing plugins (framework, twdHmr, twdRemote)
- Do NOT remove or modify existing plugins
- Show the user the changes before applying

## Step 6: Add package.json Scripts

### Always add:

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

### Option B: Custom Setup

Use the appropriate template from `skills/twd/references/ci.md`:

- **Without coverage**: Use the "Basic Workflow" template
- **With coverage**: Use the "Workflow with Coverage" template

**Customize both options:**
- Set the correct port in the `wait-on` URL
- If base path is not `/`, append it to the `wait-on` URL
- Use `dev:ci` for the server command if coverage is enabled, `dev` otherwise

## Output

When done, summarize:

- What packages were installed
- What files were created or modified
- Whether coverage was set up
- Next steps:
  - "Push to GitHub to trigger the workflow"
  - "Run `npm run test:ci` locally to verify headless tests work"
  - If coverage: "Run `npm run dev:ci` then `npm run test:ci` then `npm run collect:coverage:text` to see coverage locally"
