# Contract Validation

Read by `/twd:ci-setup` only when contract validation is enabled (Step 2.5).

`twd-cli` validates every mock response against the OpenAPI specs (3.0 or 3.1, JSON) listed in `twd.config.json`. A mock that drifts from the spec shows up as a contract error with a diff, which catches an API that changed while the mocks did not.

## Options per `contracts[]` entry

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `source` | string | — | Path to the OpenAPI spec file (JSON) |
| `baseUrl` | string | `"/"` | Base URL prefix stripped when matching mock URLs to spec paths |
| `mode` | `"error"` \| `"warn"` | `"warn"` | `error` fails the run, `warn` reports only |
| `strict` | boolean | `true` | Rejects properties the spec does not declare. Conflicts with `allOf` — use `false` there, or set `additionalProperties` explicitly |

Do not set `contractReportPath`. It is deprecated and prints a warning on every run; contract results are in the run report's `summary.md`.

## PR comment

Only the `BRIKEV/twd-cli/.github/actions/run` action posts one: `contract-report: 'true'` on the action, plus a top-level `permissions: pull-requests: write` (Step 7 has the snippet). With a custom workflow the results are in `.twd/report/summary.md` and the job summary — see `custom-workflow.md`.
