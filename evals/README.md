# Evals

Behaviour checks for the most-used skills, run with `claude plugin eval`. Each
case scaffolds a small project, gives the skill a task, and grades the files it
writes. They catch an edit that quietly reverts a rule the skills depend on.

| Case | Skill | Checks |
|---|---|---|
| `twd-flow-test` | `twd` | Runner imports, `findBy*` queries, Chai asserts, no `headers:`/`body:`, payload asserted on `rule.request`, type check and twd-lint attempted, mocks before visit |
| `twd-lint-fix` | `twd` | A hand-written test with Vitest imports, missing `await`s, `it.only` and `rule.request.body`: the skill runs twd-lint and the file ends clean |
| `twd-component-test` | `twd` | `componentHost()` helper that detaches the app root, `cleanup()` + `restorePage()` in `afterEach`, `screen` not `screenDom`, no blank-route visit, network mocked rather than project code stubbed |
| `twd-mock-component` | `twd` | A page around a camera scanner wrapped in `MockedComponent`: `twd.mockComponent()` before visit, the fake calls `onScan` with the scanner's payload, component mocks cleared in `beforeEach`, no Sinon or module mocks, the page left untouched |
| `twd-run-loop` | `twd` | A suite with one test mocking the wrong URL, run through a stand-in `twd-cli` the scaffold writes (no browser; it honours `--test` and writes `run.json`): a filtered run before the unfiltered closing run, `run.json` read, the mock fixed in the test and the app left alone |
| `twd-not-for-unit-tests` | `twd` | A Vitest unit test for a pure function, in a project that also has TWD: the skill is never invoked and the file is plain Vitest. Δ stays near zero by design; the case guards the skill's `description` |
| `setup-vite-react-query` | `setup` | The common case: `twd()` Vite plugin with a `.tsx` test pattern and no entry-file code, `twd.config.json`, `test:ci`, `.twd/` ignored, twd-lint added to the ESLint config, and `twd-patterns.md` with the type-check command and `queryClient.clear()` |
| `ci-setup-recording` | `ci-setup` | Test workflow on the `run` action, a separate label-triggered recording workflow pinned to `v1.10.0` with full history, and both starting the mock API with the same env var as a commented placeholder |

## Run

From the repository root. There are two modes.

**Quick**, while editing a skill: one run per case, with the plugin only. About
$1.80 and a few minutes. It shows an obvious break, not a flaky one.

```bash
claude plugin eval . --scaffold --trust-plugin --runs 1 --ablation none \
  --allow-tools Write Edit "Bash(npx tsc *)" "Bash(npx twd-lint *)" "Bash(npx twd-cli *)" \
  "Bash(./node_modules/.bin/*)" "Bash(node node_modules/twd-cli/bin.js *)" --no-publish
```

**Full**, before a release or when trying another model: three runs per case,
with and without the plugin. About $10 and 25 minutes, or less with `-j 3` to run three at once.

```bash
claude plugin eval . --scaffold --trust-plugin --threshold 0.9 \
  --model claude-opus-5-5 --judge-model claude-sonnet-5-5 \
  --allow-tools Write Edit "Bash(npx tsc *)" "Bash(npx twd-lint *)" "Bash(npx twd-cli *)" \
  "Bash(./node_modules/.bin/*)" "Bash(node node_modules/twd-cli/bin.js *)" --no-publish
```

Two models take part: `--model` is the agent using the skills, `--judge-model`
votes on the `llm` graders. Pin both, and change one thing per comparison:

- **A skill edit**: same agent and judge before and after, so a drop is the edit.
- **Another model**: change `--model` only and keep the judge, so a drop is the
  model. Compare `WITH` per case against the last full run on the pinned model.
  A grader that passed there and fails now is a rule the skill states too
  weakly for that model.

- A case's score is the share of its graders that passed, averaged over its
  runs. `--threshold 0.9` tolerates a grader failing once in three runs, not a
  grader that fails every time.
- `WITH` is the score with the plugin, `W/OUT` without it, and `Δ` the
  difference: what the skills add over what the model already knows. A grader
  that passes in both arms still guards against a skill edit that breaks it.
- `--case <name>` runs one case. It takes a single name or glob, not a list.
- `--keep-temp` keeps each run's workspace and `trace.jsonl`, to see what
  Claude read and wrote.
- The scaffolds write their projects from heredocs and install nothing, so a run
  needs no network, apart from `npx twd-lint` fetching the linter. The one
  `node_modules` entry is the `twd-cli` stand-in in `twd-run-loop`.
- With Node from nvm (or any install under your home), `npx` fails inside the
  eval sandbox with `Cannot find module …/bin/npx`. The type check and twd-lint
  then never run, which is why those graders check the attempt and not the
  result. `twd-run-loop` needs its runs to happen, so the two grants after
  `npx twd-cli` let the agent call the stand-in directly when `npx` fails.
  The first covers every local binary: granting only `twd-cli` there, an agent
  whose `./node_modules/.bin/twd-lint` was denied concluded nothing could run
  and stopped before running the tests.

A new case also gets a row in the Tested Scenarios table of the root
`README.md`.

Eval runs refuse writes into `.claude/`, so `setup-vite-react-query` grades
the `twd-patterns.md` write the skill attempted, from the trace, rather than the
file on disk.

## Baseline

The last full runs, to compare a skill edit or another model against: judge
`claude-sonnet-5-5`, three runs per arm, plugin 1.3.7, 2026-10-25, Node from
nvm (so `npx` failed in every run, see above). Each cell is WITH / Δ.

| Case | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 |
|---|---|---|---|
| `setup-vite-react-query` | 1.00 / +0.90 | 1.00 / +0.90 | 1.00 / +0.90 |
| `ci-setup-recording` | 1.00 / +0.70 | 1.00 / +1.00 | 0.97 / +0.80 |
| `twd-component-test` | 1.00 / +0.50 | 1.00 / +0.54 | 1.00 / +0.63 |
| `twd-run-loop` | 1.00 / +0.40 | 0.60 / 0.00 | 0.53 / -0.07 |
| `twd-lint-fix` | 1.00 / +0.14 | 1.00 / +0.24 | 1.00 / +0.52 |
| `twd-flow-test` | 0.97 / +0.10 | 1.00 / +0.27 | 0.80 / +0.37 |
| `twd-mock-component` | 1.00 / 0.00 | 1.00 / +0.29 | 0.90 / +0.48 |
| `twd-not-for-unit-tests` | 1.00 / 0.00 | 1.00 / 0.00 | 1.00 / 0.00 |

What the misses were, from the traces:

- `twd-run-loop`, Sonnet: twice it gave up when `npx` failed, after trying the
  stand-in inside a compound command the grants do not cover. The third time
  it ran the filtered run, got green, and stopped there: no closing run and
  `run.json` never read.
- `twd-run-loop`, Haiku: one run tried to read the plugin's own repository and
  every tool was denied, one never invoked the skill, one stopped after a
  denied `curl` without trying `twd-cli`.
- `twd-flow-test`, Haiku: after one denied command it decided the shell was
  off for the session and skipped the type check and lint, despite the note
  in the prompt saying otherwise.
