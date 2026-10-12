# PR Recording Workflow

Read by `/twd:ci-setup` Step 7.5 only when recording is enabled. The `record` composite action installs a known-good ffmpeg, records the tests a branch added, and uploads one clip per test.

## Workflow template

Write to `.github/workflows/twd-record.yml`, customized as Step 7.5 says.

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
        uses: BRIKEV/twd-cli/.github/actions/record@v1.10.0
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

## Action inputs

| Input | Default | Description |
|-------|---------|-------------|
| `working-directory` | `.` | Directory where `twd.config.json` lives |
| `cli-version` | `1.10.0` | `twd-cli` version to run, pinned by default |
| `changed-since` | (empty) | Record only the tests the branch added or changed since this ref. Needs `fetch-depth: 0`. Mutually exclusive with `tests` |
| `tests` | (empty) | Newline-separated test titles, each becoming one `--test` filter, OR'd. Mutually exclusive with `changed-since` |
| `pace` | (empty) | Milliseconds held after each command (`--record-pace`). Empty uses the CLI default of 300; `0` disables pacing |
| `install-ffmpeg` | `true` | Install a known-good ffmpeg 8.x. `false` uses whatever is on `PATH` |
| `upload-artifact` | `true` | Upload the clips as a workflow artifact |
| `artifact-name` | `twd-recording` | Name of the uploaded artifact |
| `retention-days` | `14` | How long to keep the artifact |

Outputs: `clip-count`, `dir`, `artifact-url`.

## Rules that are easy to get wrong

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
