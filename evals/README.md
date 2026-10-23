# Evals

Behaviour checks for the most-used skills, run with `claude plugin eval`. Each
case scaffolds a small project, gives the skill a task, and grades the files it
writes. They catch an edit that quietly reverts a rule the skills depend on.

| Case | Skill | Checks |
|---|---|---|
| `twd-flow-test` | `twd` | Runner imports, `findBy*` queries, Chai asserts, no `headers:`/`body:`, payload asserted on `rule.request`, type check and twd-lint attempted, mocks before visit |
| `twd-lint-fix` | `twd` | A hand-written test with Vitest imports, missing `await`s, `it.only` and `rule.request.body`: the skill runs twd-lint and the file ends clean |
| `twd-component-test` | `twd` | `componentHost()` helper that detaches the app root, `cleanup()` + `restorePage()` in `afterEach`, `screen` not `screenDom`, no blank-route visit, network mocked rather than project code stubbed |
| `setup-vite-react-query` | `setup` | The common case: `twd()` Vite plugin with a `.tsx` test pattern and no entry-file code, `twd.config.json`, `test:ci`, `.twd/` ignored, twd-lint added to the ESLint config, and `twd-patterns.md` with the type-check command and `queryClient.clear()` |
| `ci-setup-recording` | `ci-setup` | Test workflow on the `run` action, a separate label-triggered recording workflow pinned to `v1.10.0` with full history, and both starting the mock API with the same env var as a commented placeholder |

## Run

From the repository root. There are two modes.

**Quick**, while editing a skill: one run per case, with the plugin only. About
$1.80 and a few minutes. It shows an obvious break, not a flaky one.

```bash
claude plugin eval . --scaffold --trust-plugin --runs 1 --ablation none \
  --allow-tools Write Edit "Bash(npx tsc *)" "Bash(npx twd-lint *)" --no-publish
```

**Full**, before a release or when trying another model: three runs per case,
with and without the plugin. About $10 and 25 minutes, or less with `-j 3` to run three at once.

```bash
claude plugin eval . --scaffold --trust-plugin --threshold 0.9 \
  --allow-tools Write Edit "Bash(npx tsc *)" "Bash(npx twd-lint *)" --no-publish
```

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
  needs no network, apart from `npx twd-lint` fetching the linter.

A new case also gets a row in the Tested Scenarios table of the root
`README.md`.

Eval runs refuse writes into `.claude/`, so `setup-vite-react-query` grades
the `twd-patterns.md` write the skill attempted, from the trace, rather than the
file on disk.
