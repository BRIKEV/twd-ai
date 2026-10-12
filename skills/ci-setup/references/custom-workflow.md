# Custom GitHub Actions Workflow

Read by `/twd:ci-setup` Step 7 only when the user picks **Custom setup** (Option B) instead of the `BRIKEV/twd-cli` action. The action does the Puppeteer cache, the Chrome install, the job summary and the report upload for you; here each is a step of its own.

Pick the template, then apply the same customizations as Option A: port and base path in `wait-on`, `dev:ci` when coverage is on, and the service steps and `env:` block from Step 2.7.

Use these if you need full control over each step or aren't using GitHub Actions.

## Basic Workflow (No Coverage)

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

## Workflow with Coverage

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

## Customization Notes

- **Custom port**: Replace `5173` in `wait-on` URL with your project's port
- **Custom base path**: Append the base path to the `wait-on` URL (e.g., `http://localhost:5173/my-app/`)
- **Node version**: Adjust `node-version` to match your project
- **Package manager**: Replace `npm ci` / `npm run` with `yarn install --frozen-lockfile` / `yarn` or `pnpm install --frozen-lockfile` / `pnpm` if applicable
- **Coverage upload**: Add Codecov or Coveralls action after the coverage step if desired

## Job summary and report artifact

Every run writes `.twd/report/`. The action publishes it; a custom workflow adds these two steps after the test step, both `if: always()` so a red run still reports:

```yaml
      - name: TWD job summary
        if: always()
        run: npx twd-cli report --format markdown >> "$GITHUB_STEP_SUMMARY"

      - name: Upload TWD report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: twd-report
          path: .twd/report
```


With contracts enabled there is no PR comment outside the action: the results are in `.twd/report/summary.md`, which the job summary step above already publishes.
