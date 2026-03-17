---
name: test-quality
description: Reads TWD test files, evaluates quality across four dimensions (journeys, interactions, assertions, error handling), assigns letter grades, and generates an improvement report.
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep]
---

# Test Quality Scoring

You are evaluating **TWD test quality** — reading existing TWD test files, grading each across four weighted dimensions, and producing a report explaining what each file does well and what it's missing.

This skill answers: **"Are the existing tests any good?"** — not just whether tests exist, but whether they exercise meaningful user journeys, verify real outcomes, and handle failures.

You are **framework-agnostic** — you evaluate TWD test quality regardless of the app's framework. All scoring is based on TWD API usage patterns, not framework-specific code. This is **static analysis only** — you read test source code, you do not execute tests.

## Invocation

```
/twd:test-quality
```

No flags. No arguments. Auto-discover all TWD test files and output the full report to console. Do not accept or parse any flags.

## Workflow

### Step 1 — Pre-flight: Detect TWD presence

Glob for `**/*.twd.test.{ts,js}`.

**If zero TWD tests found → STOP.** Do not generate a report. Instead:

- Read `package.json` and scan for other test frameworks: `playwright`, `@playwright/test`, `cypress`, `jest`, `vitest`, `@testing-library/react`, `@testing-library/vue`
- If other frameworks found: output the gate message below
- If no tests at all: output the no-tests gate message below
- Either way, stop. No quality report without TWD tests.

**Gate output when other frameworks detected:**

```
## No TWD Tests Found

I found {framework} tests in this project, but no TWD test files (*.twd.test.ts).

TWD complements {framework} by adding deterministic, in-browser page-level tests
that run inside your Vite dev server — fast feedback during development with
mocked APIs, no flaky network calls.

**To get started:** run `/twd:setup` to install TWD, then `/twd` to write your
first tests.

No quality report generated — TWD tests are needed for analysis.
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

### Step 2 — Read all test files

Read each discovered TWD test file in full. For each file, analyze:

- All `it()` blocks and their content
- All `twd.visit()` calls (including in `beforeEach` — these apply to every `it()` in the same `describe` scope)
- All `userEvent.*` calls — types and frequency
- All `twd.should()` and `expect()` assertions — what they verify
- All `twd.mockRequest()` calls — methods and status codes
- `beforeEach`/`afterEach` setup patterns

### Step 3 — Grade each file

Apply the four scoring dimensions (see below) to each file. Assign a letter grade (A/B/C/D) per dimension, then compute the final grade using the weighted average formula.

### Step 4 — Generate suggestions

For each file below grade A, generate 2-3 specific, actionable suggestions to reach the next grade. Suggestions must:

- Reference the actual file content (specific endpoints, UI elements, mock data)
- Be actionable ("add a test that..." not "improve assertions")
- Target the weakest dimensions first
- Not reference patterns from other files in the project (keep it self-contained)

### Step 5 — Generate report

Output markdown to console using the output template below. Omit empty grade distribution rows. If all files are grade A, congratulate the team and skip the Improvements section.

---

## Scoring Dimensions

Each test file is graded A/B/C/D across four dimensions. The final grade is a weighted average.

### Dimension 1: Journey Coverage (35% weight)

Measures whether tests walk through complete user journeys (visit → interact → assert outcome) or merely check that elements are visible.

| Grade | Criteria |
|---|---|
| **A** | 3+ complete journeys with distinct user goals (e.g., create, search, delete) |
| **B** | 2 complete journeys, or 1 journey + significant breadth across UI sections |
| **C** | 1 complete journey covering a single happy path |
| **D** | Only visibility/rendering checks, no interaction chains |

**What counts as a "complete journey":** A test that calls `twd.visit()`, performs at least one `userEvent` interaction (click, type, select, clear), and ends with a meaningful assertion (API payload, URL change, state transition, or specific DOM content — not just `be.visible`).

**Detection signals:**
- Count `twd.visit()` calls and `userEvent.*` calls per `it()` block
- A journey has: visit + at least 1 userEvent + at least 1 non-visibility assertion
- Pure visibility tests: only `twd.should(el, "be.visible")` with no prior interaction

### Dimension 2: Interaction Depth (20% weight)

Measures the variety and realism of user interactions tested.

| Grade | Criteria |
|---|---|
| **A** | 4+ distinct interaction types (click, type, clear, keyboard, selectOptions), form submissions |
| **B** | 3 interaction types, or 2 types used across multiple flows |
| **C** | 2 interaction types (typically click + type) |
| **D** | Only `userEvent.click()` or no `userEvent` calls at all |

**Interaction types tracked:**
- `userEvent.click` — basic click
- `userEvent.type` — text input, search fields
- `userEvent.clear` — clearing input fields (tests overwrite behavior)
- `userEvent.keyboard` — keyboard navigation, enter/escape key handling
- `userEvent.selectOptions` — dropdown/select interactions
- `userEvent.dblClick` — double click
- Form submission via button click + `twd.waitForRequest()` on a POST/PUT/DELETE — full submit cycle

### Dimension 3: Assertion Quality (25% weight)

Measures whether assertions verify meaningful outcomes or just check that something is visible.

| Grade | Criteria |
|---|---|
| **A** | Verifies API request payloads (`deep.equal`), URL changes (`url().should()`), and specific attribute values |
| **B** | Verifies specific text content (`have.text`), attribute values (`have.attr`), exact counts (`have.length`), form values (`have.value`) |
| **C** | Mix of `be.visible` and specific text checks, but no payload or state verification |
| **D** | Only `be.visible` and loose count assertions like `greaterThan(1)` |

**Assertion hierarchy (weakest → strongest):**
1. `be.visible` — element exists and is shown (weakest)
2. `greaterThan(N)` — loose count check
3. `have.length(N)` — exact count
4. `have.text("exact text")` — specific content
5. `have.value("exact value")` — form state
6. `have.attr("href", "/path")` — link/attribute verification
7. `be.disabled` / `not.be.disabled` — interactive state
8. `expect(el).to.be.null` — absence verification
9. `twd.url().should("contain.url", "...")` — URL state verification
10. `expect(rule.request).to.deep.equal(...)` — API payload verification (strongest)

The grade is determined by the **highest level used in 2+ test blocks** across the file, not by a single isolated occurrence. Look at the overall distribution of assertion types — a file that mostly uses `be.visible` with one `deep.equal` is still grade C/D, not A.

### Dimension 4: Error & Edge Case Coverage (20% weight)

Measures whether tests handle failure scenarios and boundary conditions.

| Grade | Criteria |
|---|---|
| **A** | Tests API errors (400/500), empty states, and cancel/abort flows |
| **B** | Tests 2 of: error responses, empty states, cancel flows |
| **C** | Tests 1 edge case |
| **D** | Only happy path with status 200, single data shape |

**Detection signals:**
- `status: 400` or `status: 500` in `mockRequest` → error state testing
- `response: { results: [] }` or `count: 0` or empty array → empty state testing
- `expect(el).to.be.null` after an action → verifying removal/hiding
- Dialog cancel flow: open → Cancel → verify closed
- Multiple mock data shapes for the same endpoint

---

## Final Grade Calculation

Convert dimension grades to numbers (A=4, B=3, C=2, D=1), compute weighted average, map back to letter:

| Weighted Average | Final Grade |
|---|---|
| 3.5 or higher | **A** |
| 2.5 – 3.49 | **B** |
| 1.5 – 2.49 | **C** |
| Below 1.5 | **D** |

The overall project grade is the average of all file grades.

---

## Output Template

```markdown
# TWD Test Quality Report
Generated: {date}
Files analyzed: {N}
Overall grade: {X}

## Grade Distribution
| Grade | Count | Files |
|---|---|---|
| A | N | file1, file2 |
| B | N | ... |
| C | N | ... |
| D | N | ... |

## Per-File Breakdown

### {filename} — Grade {X}
| Dimension | Grade | Notes |
|---|---|---|
| Journey Coverage | {A-D} | ... |
| Interaction Depth | {A-D} | ... |
| Assertion Quality | {A-D} | ... |
| Error & Edge Cases | {A-D} | ... |

**To reach grade {next}:** {2-3 specific suggestions referencing this file's content}

---

## Improvements
Ranked by impact (lowest-graded files first):
1. **{file}** (Grade D): {what to improve and why it matters}
2. ...

---

> Run `/twd:test-gaps` to find pages with no tests at all.
```

---

## Grade-Up Suggestions

For each file below grade A, generate 2-3 specific suggestions to reach the next grade.

**Suggestion patterns by dimension:**

Journey Coverage suggestions:
- "Add a test that completes the [action] flow: [specific steps based on what the page does]"
- "Add a test for [user goal] — the page has [element] but no test exercises it"

Interaction Depth suggestions:
- "Add `userEvent.clear(input)` before typing to test overwrite behavior"
- "Add `userEvent.keyboard('[Escape]')` to test [modal/dropdown] dismissal"
- "Add `userEvent.selectOptions` for the [dropdown element] on this page"

Assertion Quality suggestions:
- "Replace `greaterThan(1)` with exact `have.length(N)` for [element]"
- "Add `expect(rule.request).to.deep.equal({...})` to verify the [POST/PUT] payload"
- "Add `twd.url().should('contain.url', '...')` to verify URL updates on [action]"

Error & Edge Case suggestions:
- "Add a test mocking `status: 500` on `[endpoint]` and verify the error state"
- "Add a test with empty response for `[endpoint]` and verify the empty state message"
- "Add a cancel flow test: open [dialog/form] → click Cancel → verify it closes"

---

## Full Example

### Example output

```markdown
# TWD Test Quality Report
Generated: 2026-03-17
Files analyzed: 8
Overall grade: C

## Grade Distribution
| Grade | Count | Files |
|---|---|---|
| A | 2 | user-list.twd.test.ts, order-list.twd.test.ts |
| B | 2 | dashboard.twd.test.ts, item-detail.twd.test.ts |
| C | 2 | product-config.twd.test.ts, billing.twd.test.ts |
| D | 2 | payment-list.twd.test.ts, item-create.twd.test.ts |

---

### user-list.twd.test.ts — Grade A
| Dimension | Grade | Notes |
|---|---|---|
| Journey Coverage | A | 7 tests: table display, search with debounce, column toggle, actions menu, delete flow, pagination, empty state |
| Interaction Depth | A | click, type, keyboard (Enter/Escape), selectOptions for column selector |
| Assertion Quality | A | Column headers by index, cell text values, URL contains query param, deep.equal on DELETE payload |
| Error & Edge Cases | B | Empty search response tested, delete confirmation; missing: API 500 on delete |

**To reach A across all dimensions:** Add a test mocking `status: 500` on the `DELETE /api/users/:id` endpoint and verify the error state is displayed.

---

### payment-list.twd.test.ts — Grade D
| Dimension | Grade | Notes |
|---|---|---|
| Journey Coverage | D | 1 test — visits page, checks heading is visible, counts rows with greaterThan(1) |
| Interaction Depth | D | No userEvent calls at all |
| Assertion Quality | D | Only be.visible and greaterThan(1) — weakest assertions |
| Error & Edge Cases | D | Only happy path with status 200 |

**To reach grade C:** Add a test that searches the payment list — `userEvent.type` in the search field, verify URL updates with `twd.url().should()`. Add column header assertions with `have.text` to verify specific content instead of just visibility.

---

## Improvements
1. **payment-list.twd.test.ts** (Grade D): Core financial module with only a visibility check. Add search interaction, column header verification, and row data assertions.
2. **item-create.twd.test.ts** (Grade D): Creation flow has no form interaction tests. Add fill form → submit → verify POST payload flow.
3. **product-config.twd.test.ts** (Grade C): Multi-tab page only tests first tab. Add tab switching with click + content verification for each tab.
4. **billing.twd.test.ts** (Grade C): Financial data display — add error state test (mock 500) and empty state test.

---

> Run `/twd:test-gaps` to find pages with no tests at all.
```

**Key observations from this example:**
- Grade A file still has one B dimension — the per-dimension breakdown shows exactly where
- Grade D file gets specific suggestions referencing its actual content (search field, column headers)
- Improvements section ranks D files first, then C files
- No time estimates — just what to do and why
- Cross-reference to test-gaps at the bottom

---

## Limitations

1. **Static analysis only.** Scoring is based on reading test source code. No test execution. Cannot detect runtime issues like flaky assertions or timing problems.
2. **Heuristic grading.** Letter grades are AI interpretation of the criteria, not deterministic computation. Two runs may produce slightly different notes, but grades should be consistent for the same file.
3. **TWD only.** Only scores `*.twd.test.{ts,js}` files. Tests in other frameworks are invisible.
4. **No cross-file analysis.** Each file is scored independently. Cannot detect project-wide patterns like "all files lack error tests."
5. **No permission/access dimension in v1.** RBAC testing quality is not scored. If the project uses permission mocking, this is noted in the Journey Coverage notes but doesn't have its own dimension.
