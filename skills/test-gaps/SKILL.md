---
name: test-gaps
description: Scans project routes and cross-references against TWD test files to find untested pages, classify risk, and generate a prioritized gap report.
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep]
---

# Test Gap Analysis

You are performing a **Test Gap Analysis** — scanning a project to find all pages/routes and cross-referencing them against existing TWD test files. Your output is a prioritized markdown report answering: **which pages have no tests, and which matter most?**

You are **framework-agnostic** — you work with any project that uses TWD tests, regardless of whether the app uses React, Vue, Angular, Next.js, Nuxt, SolidJS, or any other framework. TWD tests describe user behavior, not framework internals.

## Invocation

```
/twd:test-gaps
```

No flags. No arguments. Auto-discover everything and output the full report to console. Do not accept or parse any flags.

## Workflow

### Step 1 — Pre-flight: Detect TWD presence

Glob for `**/*.twd.test.{ts,tsx,js}`.

**If zero TWD tests found → STOP.** Do not generate a report. Instead:

- Read `package.json` and scan for other test frameworks: `playwright`, `@playwright/test`, `cypress`, `jest`, `vitest`, `@testing-library/react`, `@testing-library/vue`
- If other frameworks found: output the gate message below
- If no tests at all: output the no-tests gate message below
- Either way, stop. No gap report without TWD tests.

**Gate output when other frameworks detected:**

```
## No TWD Tests Found

I found {framework} tests in this project, but no TWD test files (*.twd.test.{ts,tsx}).

TWD complements {framework} by adding deterministic, in-browser page-level tests
that run inside your Vite dev server — fast feedback during development with
mocked APIs, no flaky network calls.

**To get started:** run `/twd:setup` to install TWD, then `/twd` to write your
first tests.

No gap report generated — TWD tests are needed for analysis.
```

**Gate output when no tests at all:**

```
## No Tests Found

This project has no TWD tests and no other test framework detected.

Shipping without tests means bugs reach users undetected. Pages with forms,
payments, or access control are especially risky — a single untested mutation
can corrupt data silently.

**To get started:** run `/twd:setup` to install TWD, then `/twd` to write
tests for your highest-risk pages first.
```

### Step 2 — Discover all routes

Use three strategies in priority order. Try Strategy A first. If it yields no routes, try B. If B yields nothing, fall back to C.

**Strategy A: Framework route config (preferred)**

Detect framework from `package.json` dependencies, then find and read the route config:

| Framework | Typical route file | What to extract |
|---|---|---|
| React Router | `routes.tsx`, `AppRoutes.tsx`, `router.tsx` | `path`, `element`/`component` |
| Vue Router | `router/index.ts`, `router.ts` | `path`, `component` |
| Angular | `app-routing.module.ts`, `app.routes.ts` | `path`, `component` |
| SolidJS | `routes.tsx` | `path`, `component` |
| Next.js (App Router) | `app/**/page.tsx` | directory structure = routes |
| Nuxt | `pages/**/*.vue` | file structure = routes |

For file-based routing (Next.js App Router, Nuxt), the directory/file structure IS the route config — glob for page files and derive routes from paths.

**Strategy B: Page component glob (fallback)**

If no framework route config is found, glob for page components in common patterns:
- `src/pages/**/*.{tsx,vue,svelte}`
- `app/**/page.{tsx,jsx,ts,js}`
- `pages/**/*.{tsx,vue,svelte}`

Each file represents a likely route. Derive the route path from the file path.

**Strategy C: TWD tests only (last resort)**

If neither A nor B yields results, use only TWD test `twd.visit()` URLs as the known route universe. Add a prominent warning banner to the report:

```
> ⚠️ **Route discovery: TWD tests only.** No route config or page components found.
> This report shows tested routes but CANNOT identify untested pages.
> Consider adding a route config or organizing pages in a standard directory structure.
```

In this mode, the UNTESTED section is omitted entirely since there's no route universe to compare against. The PARTIALLY TESTED section still works (visit-only detection).

### Step 3 — Discover tested routes

Read all TWD test files found in Step 1. For each file, extract:

- **All `twd.visit()` calls** — URL strings (string literals, template literals, same-file constant references). Include `visit()` calls inside `beforeEach` blocks — these apply to every `it()` in the same `describe` scope.
- **All `twd.mockRequest()` calls** — method + URL for each mock (including those in `beforeEach`)
- **Interaction depth** — does the test have `userEvent.*` calls (click, type, clear, selectOptions, keyboard, dblClick) or is it visit-only?

**Component tests cover no route.** A file that calls Testing Library's `render()` and never `twd.visit()` tests a component in isolation. It adds nothing to the tested-route set — do not credit the page that uses the component. Mention the components it covers in that page's "What's Covered" cell when the page is otherwise partially tested.

**URL extraction rules:**

| Pattern | How to extract |
|---|---|
| `twd.visit("/checkout")` | Literal string `/checkout` |
| `twd.visit(\`/orders/${id}\`)` | Replace `${...}` with `:param` → `/orders/:param` |
| `twd.visit(CHECKOUT_URL)` | Trace `const CHECKOUT_URL = "..."` in same file |
| Variable from import | Cannot resolve — note as "unresolved visit URL" |

### Step 4 — Match and classify

**4a. Match routes to tests**

| Strategy | How it works |
|---|---|
| Exact URL match | Strip base path from `visit()` URLs, compare to route paths |
| Parameterized match | Replace `${var}` in visit URLs with `:param` wildcard, match route patterns |
| File naming fallback | Match test directory/file name to route segment (e.g., `checkout/` → `/checkout`) |

**4b. Classify coverage status**

- **TESTED** — route has a matching test file with `twd.visit()` and `userEvent.*` interactions
- **PARTIALLY TESTED** — route has tests but:
  - Tests only visit the page with no `userEvent.*` interactions (visit-only)
  - Route component has forms/mutations but no test mocks POST/PUT/PATCH/DELETE requests
- **UNTESTED** — route has zero matching test files

### Step 5 — Risk classification

For each UNTESTED and PARTIALLY TESTED route, read the component file to classify risk.

**HIGH — Test this first**

Any of these is true:
- **Has mutations** — forms, POST/PUT/PATCH/DELETE API calls, data creation/updates/deletes
- **Handles money** — payments, refunds, billing, subscriptions, pricing
- **Write-permission-gated** — elevated permissions for destructive actions

**MEDIUM — Test this soon**

Any of these is true:
- **Has access control** — permission-gated, role-based, auth-required
- **Complex data loading** — multiple API calls, deferred/streaming data
- **Detail page with multiple views** — tabs, modals, conditional sections
- **Custom caching/revalidation** — non-standard data refresh behavior

**LOW — Nice to have**

- **Read-only display** — simple data display, no interactions
- **Error/utility pages** — 404, 403, maintenance
- **Static pages** — no data fetching, no user input

### Step 6 — Generate report

Output markdown to console using the output template below. Omit empty sections (e.g., if no HIGH risk gaps, skip that subsection). If all routes are covered, congratulate the team and note any partial coverage that could be improved.

**"Start Here" ranking:** HIGH risk first, then PARTIAL over UNTESTED at the same risk level, then by mutation density (more form actions = higher priority within the same tier).

**Monorepo note:** v1 assumes a single-app project. If the repo appears to be a monorepo (multiple `package.json` files, `apps/` or `packages/` directory), note this in the report and analyze only the root-level app or ask the user which app to scan.

---

## Output Template

```markdown
# Test Gap Analysis Report
Generated: {date}

## Summary
- **Pages/routes discovered:** {N}
- **Pages with tests:** {N}
- **Pages partially tested:** {N}
- **Pages untested:** {N}
- **Route discovery method:** {framework route config / page component glob / TWD tests only}

## UNTESTED Pages

### HIGH Risk
| Page | Path | Why High Risk |
|------|------|---------------|
| ... | ... | ... |

### MEDIUM Risk
| Page | Path | Why Medium Risk |
|------|------|-----------------|
| ... | ... | ... |

### LOW Risk
| Page | Path | Why Low Risk |
|------|------|--------------|
| ... | ... | ... |

## PARTIALLY TESTED Pages
| Page | Path | What's Covered | What's Missing |
|------|------|----------------|----------------|
| ... | ... | ... | ... |

## Start Here (Top 5 Priorities)
1. **{Page}** — {reason this is #1}
2. ...

---

> **Tip:** For large codebases, the Serena MCP server can reduce token usage
> during gap analysis by enabling symbol-level navigation instead of full file reads.
```

---

## Partial Coverage Detection

A route is PARTIALLY TESTED when:

| Signal | What it means |
|---|---|
| Test has `twd.visit()` but zero `userEvent.*` calls | Visit-only test — page loads but no interactions verified |
| Route component has forms/submit handlers but test has no POST/PUT/PATCH/DELETE mocks | Mutations exist but are untested |

This is deliberately simple. Full quality analysis (happy-path-only detection, error state coverage, multi-view coverage) is out of scope.

---

## Full Example

### Example output

```markdown
# Test Gap Analysis Report
Generated: 2026-03-17

## Summary
- **Pages/routes discovered:** 22
- **Pages with tests:** 15
- **Pages partially tested:** 2
- **Pages untested:** 5
- **Route discovery method:** React Router config (src/routes.tsx)

## UNTESTED Pages

### HIGH Risk
| Page | Path | Why High Risk |
|------|------|---------------|
| User Settings | /settings/account | Has form mutations (update profile, change password, delete account) |
| Admin Role Create | /admin/roles/create | Creates RBAC roles affecting permissions for all users |
| Checkout | /checkout | Handles payments — direct financial impact |

### MEDIUM Risk
| Page | Path | Why Medium Risk |
|------|------|-----------------|
| Billing Detail | /billing/:id | Financial data display with nested detail views |
| Product Config | /products/:id/config | Detail page with multiple tabs and conditional sections |

## PARTIALLY TESTED Pages
| Page | Path | What's Covered | What's Missing |
|------|------|----------------|----------------|
| Order Detail | /orders/:id | Page loads, data displays | No userEvent interactions — forms and buttons untested |
| Dashboard | / | Card links verified | Page has POST /api/dashboard/settings mock but no form interaction tests |

## Start Here (Top 5 Priorities)
1. **Checkout** — Handles payments. Zero tests. A bug here costs real money.
2. **Admin Role Create** — Creates RBAC roles. Zero tests. A bug affects access for all users.
3. **User Settings** — Has delete account flow. Zero tests. Untested destructive action.
4. **Order Detail** — Most visited detail page. Has tests but no interaction coverage.
5. **Billing Detail** — Financial data. Zero tests. Nested route may have edge cases.

---

> **Tip:** For large codebases, the Serena MCP server can reduce token usage
> during gap analysis by enabling symbol-level navigation instead of full file reads.
```

**Key observations from this example:**
- Route discovery used React Router config — the most reliable strategy
- 5 untested pages found, classified by risk (3 HIGH, 2 MEDIUM, 0 LOW)
- 2 partially tested pages — one is visit-only, one has mocks but no form interactions
- "Start Here" priorities rank HIGH risk first, then by mutation density
- Empty sections (LOW risk) are omitted
- Serena tip included at the bottom

---

## Limitations

1. **TWD only.** Only scans `*.twd.test.{ts,tsx,js}` files. Tests in other frameworks (Vitest, Playwright, Cypress, Jest) are invisible to the gap analysis (but detected during pre-flight).
2. **Heuristic route matching.** Route-to-test matching is best-effort. Cannot trace runtime navigation or dynamic route registration.
3. **No quality analysis.** A route with a single `be.visible` assertion shows as TESTED same as one with 20 thorough tests. Partial detection is limited to visit-only and missing mutation mocks.
4. **Variable resolution is same-file only.** Cannot follow imported URL constants across modules.
5. **Risk classification is heuristic.** Based on reading component code — may miss business context (e.g., a "simple" page that's actually critical for compliance).
