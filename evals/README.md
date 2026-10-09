# Evals

Behaviour checks for the most-used skills, run with `claude plugin eval`. Each
case scaffolds a small project, gives the skill a task, and grades the files it
writes. They catch an edit that quietly reverts a rule the skills depend on.

| Case | Skill | Checks |
|---|---|---|
| `twd-flow-test` | `twd` | One top-level `describe`, runner imports, `findBy*` queries, Chai asserts, no `headers:`/`body:`, payload asserted on `rule.request`, type check attempted, mocks before visit |
| `twd-component-test` | `twd` | `componentHost()` helper that detaches the app root, `cleanup()` + `restorePage()` in `afterEach`, `screen` not `screenDom`, no blank-route visit, network mocked rather than project code stubbed |
| `setup-angular` | `setup` | `TWD_ENABLED` define guard (never `isDevMode()`), the define in `angular.json`, `initTWD` before bootstrap, a `Type-check command` in `twd-patterns.md`, port 4200 |
| `ci-setup-recording` | `ci-setup` | Test workflow on the `run` action, a separate label-triggered recording workflow pinned to `v1.10.0` with full history, and both starting the mock API with the same env var as a commented placeholder |

## Run

From the repository root:

```bash
claude plugin eval . --scaffold --trust-plugin --ablation none \
  --allow-tools Write Edit "Bash(npx tsc *)" --no-publish
```

- `--case <name>` runs one case. It takes a single name or glob, not a list.
- Drop `--ablation none` to add a run without the plugin and see what the skills add.
- A full run of the four cases costs about $1.50 and takes a few minutes. Run it
  before a release, or after changing a skill these cases cover, not on every PR.
- The scaffolds write their projects from heredocs and install nothing, so a run
  needs no network.

Eval runs refuse writes into `.claude/`, so `setup-angular` grades the
`twd-patterns.md` write the skill attempted, from the trace, rather than the
file on disk.
