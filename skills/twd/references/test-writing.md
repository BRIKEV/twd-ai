# TWD Test Writing Reference

TWD tests run inside the app's own dev server: the real app and component tree, with every external dependency (network, third-party providers, viewport) mocked or controlled by the test. TWD is **complementary to Playwright/Cypress**, not a replacement — never write Playwright-style tests with it. Tests run headlessly with `twd-cli` (see `running-tests.md`).

This file is the core: enough for most tests. Read **`test-api.md`** when you need more — URL matching beyond a plain path, regex URLs, waiting on the same request twice, `twd.waitFor`, Sinon module stubbing, uncommon interactions (`setInputValue`, `upload`, `hover`) or assertions (`be.focused`, `be.hidden`…), or when a failure points at how an API was used.

### Imports

```typescript
import { twd, userEvent, screenDom, expect } from "twd-js";
import { describe, it, beforeEach, afterEach } from "twd-js/runner";
```

NEVER import `describe`, `it`, `beforeEach`, `expect` from Jest, Mocha, Vitest, or other libraries.

### File Rules

- Location: `src/twd-tests/` (organize by domain for larger projects)
- Naming: `*.twd.test.ts` (or `*.twd.test.tsx` if using JSX in mocks or Testing Library `render()`).
  The `twd()` plugin's default `testFilePattern` is `'/**/*.twd.test.ts'`, which matches `.ts` ONLY —
  a `.tsx` file needs `twd({ testFilePattern: '/**/*.twd.test.{ts,tsx}' })` or it is skipped silently
- **ONE top-level `describe()` per file** — use nested `describe()` for sub-scenarios

### Element Selection Priority

**Query variant — `findBy*` first.** UI in a real app renders asynchronously (after navigation, fetches, state updates), so default to the variant that waits:

1. `await screenDom.findBy*(...)` — waits for the element to appear. **The default.** `findAllBy*` for lists
2. `screenDom.getBy*(...)` — synchronous, throws at once. Only when the element is certainly already rendered
3. `screenDom.queryBy*(...)` — returns `null`. **Only** to assert that something is absent

**Query type — by what the user perceives:**

1. `ByRole("button", { name: "Submit" })` — by ARIA role (preferred)
2. `ByLabelText("Email")` — form inputs by label
3. `ByText("Success!")` — by visible text
4. `ByTestId("user-card")` — by test ID (last resort)
5. `await twd.get("#id")` / `await twd.get(".class")` — CSS selector fallback, after every Testing Library query

For portals/modals: use `screenDomGlobal` instead of `screenDom`.

### Standard `mockRequest` Pattern

```typescript
// Always mock BEFORE twd.visit()
await twd.mockRequest("labelName", {
  method: "GET",
  url: "/api/endpoint",
  response: { data: "value" },
  status: 200,
});
await twd.visit("/page");
await twd.waitForRequest("labelName");
```

- `url` is boundary-aware string matching: `/api/users` matches `/api/users?page=1` but not `/api/users/123` or `/api/users-x`. Prefer string URLs; hardcode dynamic IDs (`/api/users/456`). `urlRegex: true` only as a last resort — see `test-api.md`.
- `await twd.waitForRequest("alias")` returns the rule; **`rule.request` is the parsed body** — `expect(rule.request).to.deep.equal({...})`, never `rule.request.body`.
- Response headers go in `responseHeaders` (`headers` is silently ignored). `status: 0` simulates a network failure.
- The service worker intercepts cross-origin requests too — mock third-party URLs the same way.
- When `waitForRequest` times out: `twd.getRequestCounts()` — `0` for the alias means the URL or method never matched.

### Assertions — Chai Style (NEVER Jest)

TWD uses **Chai** assertions via `expect` from `twd-js`. Never use Jest-style matchers.

```typescript
// RIGHT — Chai style
expect(array).to.have.length(3);
expect(value).to.equal("expected");
expect(obj).to.deep.equal({ key: "value" });
expect(flag).to.be.true;

// WRONG — Jest style (these will throw errors)
expect(array).toHaveLength(3);      // WRONG
expect(value).toBe("expected");     // WRONG
expect(obj).toEqual({ key: "v" });  // WRONG
expect(flag).toBeTruthy();          // WRONG
```

### Standard `beforeEach`

```typescript
beforeEach(() => {
  twd.clearRequestMockRules();
  twd.clearComponentMocks();
  // Reset app state if needed — see "State Isolation" below
});
```

### Standard Template

```typescript
import { twd, userEvent, screenDom, expect } from "twd-js";
import { describe, it, beforeEach } from "twd-js/runner";

const mockData = [
  { id: 1, name: "Item One" },
  { id: 2, name: "Item Two" },
];

describe("Feature Page", () => {
  beforeEach(() => {
    twd.clearRequestMockRules();
    twd.clearComponentMocks();
    // Reset app state if needed — see "State Isolation" below
  });

  it("should load and display items", async () => {
    await twd.mockRequest("getItems", {
      method: "GET",
      url: "/api/items",
      response: mockData,
      status: 200,
    });

    await twd.visit("/items");
    await twd.waitForRequest("getItems");

    twd.should(await screenDom.findByRole("heading", { name: "Items" }), "be.visible");
    expect(await screenDom.findAllByRole("listitem")).to.have.length(2);
  });

  it("should show empty state", async () => {
    await twd.mockRequest("getItems", {
      method: "GET",
      url: "/api/items",
      response: [],
      status: 200,
    });

    await twd.visit("/items");
    await twd.waitForRequest("getItems");

    twd.should(await screenDom.findByText(/no items found/i), "be.visible");
  });
});
```

### Async/Await (Required)

```typescript
// These are ALL async — ALWAYS await
await twd.visit("/page");
await twd.get("button");
await twd.getAll(".item");
await userEvent.click(button);
await userEvent.type(input, "text");
await screenDom.findByRole("button");
await twd.mockRequest("alias", { method, url, response, status });
await twd.waitForRequest("label");
await twd.waitFor(() => expect(el).to.have.attribute("disabled"));
await twd.notExists(".spinner");
```

### State Isolation

`twd.visit()` is an SPA navigation (History API), not a page reload — a reload would destroy the test runner, which lives in the same page. So in-memory app state **persists between tests** unless `beforeEach` resets it:

| State | Reset in `beforeEach` |
|---|---|
| Stores (Zustand, Redux, Jotai, Pinia) | The store's reset method |
| Query caches (TanStack Query, SWR, Apollo, RTK Query) | The cache singleton's clear — see `.claude/twd-patterns.md` |
| localStorage / sessionStorage | `localStorage.clear()` |
| Module singletons | Re-assign to the initial value |

Listeners and timers the app registers globally are removed in `afterEach`.

### Component Mocking and Module Stubbing

- Replacing a third-party component (payment SDK, map, video player): `test-advanced.md` — `MockedComponent`, `twd.mockComponent()` **before** `twd.visit()`, `twd.clearComponentMocks()` in `beforeEach`.
- Stubbing a hook or module (`useAuth0`, feature flags): `test-api.md` "Module Stubbing with Sinon". Sinon is its own package (`import Sinon from "sinon"`, never `twd-js/sinon`), and only default-export objects can be stubbed.

### Mistakes the type checker will not catch

In a TypeScript project, the type-check step (Phase 3) catches `body:` instead of `response:`, positional `mockRequest` arguments, `headers:` and Jest matchers. In a JavaScript project nothing does — check those by eye. The type checker never catches these:

1. A missing `await` on any call in the async list above
2. `mockRequest` or `mockComponent` registered after `twd.visit()`
3. `rule.request.body.x` — `rule.request` is already the body
4. Runner imports from Jest, Vitest or Mocha instead of `twd-js/runner`
5. More than one top-level `describe()` in a file
6. Node APIs (`fs`, `path`) — tests run in the browser
7. App state not reset in `beforeEach` (see State Isolation)
8. A regex URL where a string would match
9. `it.only()` left in a file — isolate with `npx twd-cli run --test "name"` instead
