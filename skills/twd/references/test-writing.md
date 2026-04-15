# TWD Test Writing Reference

TWD (Test While Developing) is a **deterministic, in-browser testing tool** that runs inside the app's own Vite dev server. Tests are deterministic because all external dependencies — network requests, third-party providers, viewport size — are mocked or controlled by the test. It is **complementary to Playwright/Cypress** — use TWD for fast component and page-level tests with mocked APIs during development; use Playwright/Cypress for full E2E flows across pages, real network, and cross-browser validation. Do NOT treat TWD as a Playwright replacement or write Playwright-style tests with it.

> **Runners**: TWD has two runners — **`twd-relay`** (dev) connects via WebSocket to the browser tab you already have open, and **`twd-cli`** (CI) launches a headless browser via Puppeteer. Both execute the same tests. See `running-tests.md` for details.

## Quick Reference

Everything you need for most tests. Only read past this section if you need component mocking, Sinon stubbing, or advanced patterns.

### Imports

```typescript
import { twd, userEvent, screenDom, expect } from "twd-js";
import { describe, it, beforeEach, afterEach } from "twd-js/runner";
```

NEVER import `describe`, `it`, `beforeEach`, `expect` from Jest, Mocha, Vitest, or other libraries.

### File Rules

- Location: `src/twd-tests/` (organize by domain for larger projects)
- Naming: `*.twd.test.ts` (or `*.twd.test.tsx` if using JSX in mocks)
- **ONE top-level `describe()` per file** — use nested `describe()` for sub-scenarios

### Element Selection Priority

1. `screenDom.getByRole("button", { name: "Submit" })` — by ARIA role (preferred)
2. `screenDom.getByLabelText("Email")` — form inputs by label
3. `screenDom.getByText("Success!")` — by visible text
4. `screenDom.getByTestId("user-card")` — by test ID (last resort)
5. `await twd.get("#id")` / `await twd.get(".class")` — CSS selector fallback

For async elements: `await screenDom.findByRole(...)` (waits for element).
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

> **Important**: `mockRequest` always needs `await`. The second argument uses `response` (NOT `body`). The signature is: `await twd.mockRequest("alias", { method, url, response, status?, headers?, responseHeaders?, delay?, urlRegex? })`. The `response` field accepts any value — objects, arrays, strings, `null`, etc.

> **Debugging mock matches**: `twd.getRequestCount("alias")` returns how many times a mock was hit. `twd.getRequestCounts()` returns `{ alias: count, ... }` for all mocks. Use these when `waitForRequest` times out to check if the URL/method is matching. Counters reset with `twd.clearRequestMockRules()`.

> **Cross-origin requests**: The mock service worker intercepts **all** requests made from the page, including cross-origin URLs (e.g., third-party APIs like payment providers or analytics services). You can mock any URL your frontend calls, regardless of domain.

#### Full `mockRequest` Options

```typescript
await twd.mockRequest("alias", {
  method: string,              // HTTP method (GET, POST, PUT, DELETE, etc.)
  url: string | RegExp,        // URL to match
  response: unknown,           // Response body (any JSON-serializable value)
  status?: number,             // HTTP status code (default: 200)
  headers?: Record<string, string>,         // Response headers
  responseHeaders?: Record<string, string>, // Alternative name for headers
  delay?: number,              // Simulated network delay in ms
  urlRegex?: boolean,          // Enable regex matching for url (default: false)
});
```

#### WRONG vs RIGHT — `mockRequest`

```typescript
// WRONG — positional arguments (this API does NOT exist)
twd.mockRequest("GET", "/api/users", { data: [] }, 200);

// WRONG — using "body" instead of "response"
await twd.mockRequest("getUsers", {
  method: "GET",
  url: "/api/users",
  body: { data: [] },  // WRONG: the key is "response", not "body"
  status: 200,
});

// WRONG — missing await
twd.mockRequest("getUsers", {
  method: "GET",
  url: "/api/users",
  response: { data: [] },
  status: 200,
});

// RIGHT — alias + config object, await, response
await twd.mockRequest("getUsers", {
  method: "GET",
  url: "/api/users",
  response: { data: [] },
  status: 200,
});

// RIGHT — with optional fields
await twd.mockRequest("slowRequest", {
  method: "GET",
  url: "/api/data",
  response: { items: [] },
  status: 200,
  delay: 1000,
  responseHeaders: { "X-Request-Id": "abc-123" },
});

// WRONG — unnecessary regex (string match already handles boundaries)
await twd.mockRequest("getUser", {
  method: "GET",
  url: /^\/api\/users$/,
  urlRegex: true,
  response: { id: 1, name: "User" },
});

// RIGHT — string match handles this automatically
await twd.mockRequest("getUser", {
  method: "GET",
  url: "/api/users",
  response: { id: 1, name: "User" },
});
```

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
  // Reset app state if needed — see "State Management & Test Isolation" below
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
    // Reset app state if needed — see "State Management & Test Isolation" below
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

    twd.should(screenDom.getByRole("heading", { name: "Items" }), "be.visible");
    expect(screenDom.getAllByRole("listitem")).to.have.length(2);
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

    twd.should(screenDom.getByText(/no items found/i), "be.visible");
  });
});
```

---

## Detailed API Reference

### Testing Philosophy: Flow-Based Tests

TWD tests focus on **full user flows**, not granular unit-style assertions. Each `it()` block tests a meaningful user journey through a page.

#### Do

- **One top-level `describe()` per file** — use nested `describe()` for sub-scenarios.
- Each `it()` covers a **complete flow**: setup mocks → visit → interact → assert outcome.
- **Multiple assertions per `it()` are expected** — they should tell a story. If you're on the same page with the same mock setup, assert everything there instead of splitting into separate tests.
- **Combine related checks** — verifying that a page shows a title, a table, and a button is ONE test ("should load and display the payments list"), not three.
- **Name `it()` blocks after the user journey**, not after individual elements:
  - `"should load the payment list and display all columns"`
  - `"should open the create form, fill fields, and submit successfully"`
  - `"should show validation errors when submitting an empty form"`

#### Don't

- **Don't write one `it()` per UI element** — "should display title", "should display subtitle", "should display button" is three tests that should be one.
- **Don't create separate tests for trivially combinable checks** — if two assertions share the same setup (same mocks, same page, same state), combine them.
- **Don't test implementation details** — test what the user sees and does, not internal component state.
- **Don't name tests after elements** — `"should display Pre payment label"` describes an element, not a flow.

#### Aim for 3–6 Tests per Feature

Most features can be fully covered with 3–6 `it()` blocks organized into these categories:

| # | Category | What it covers | Example `it()` name |
|---|----------|---------------|---------------------|
| 1 | **Happy path A** | Main flow end-to-end | `"should load the list and display all items"` |
| 2 | **Happy path B** | Reverse or alternate flow | `"should edit an existing item and save changes"` |
| 3 | **Cancel / negative flow** | User aborts or submits invalid data | `"should cancel creation and return to the list"` |
| 4 | **Access gates** | Feature flag + permission combined | `"should redirect to forbidden when user lacks permission"` |
| 5 | **Edge cases** | Empty states, errors, backward compat (combine into 1–2 tests) | `"should display empty state when no items exist"` |

If you're writing 10+ tests for a single page, you're likely too granular. Look for tests that can be combined.

#### Good Example — Flow-Based `it()` Names

```typescript
describe("Payments Page", () => {
  beforeEach(() => { /* ... */ });

  describe("listing", () => {
    it("should load the payment list and display all columns", async () => {
      // Mock GET → visit → wait → assert heading, table rows, column headers
    });

    it("should display empty state when no payments exist", async () => {
      // Mock GET with [] → visit → wait → assert empty message
    });
  });

  describe("create flow", () => {
    it("should open the create form, fill fields, and submit successfully", async () => {
      // Mock GET + POST → visit → click Add → fill form → submit → assert POST body + success
    });

    it("should show validation errors when submitting an empty form", async () => {
      // Mock GET → visit → click Add → submit empty → assert error messages
    });

    it("should cancel creation and return to the list", async () => {
      // Mock GET → visit → click Add → click Cancel → assert list is visible
    });
  });
});
```

#### Bad Example — Granular Per-Element Tests (NEVER do this)

```typescript
// BAD — each it() tests a single element instead of a flow
describe("Payments Page", () => {
  it("should display Pre payment label", async () => { /* ... */ });
  it("should display the payment amount", async () => { /* ... */ });
  it("should display the payment date", async () => { /* ... */ });
  it("should display the status badge", async () => { /* ... */ });
  it("should display the submit button", async () => { /* ... */ });
  it("should display the cancel button", async () => { /* ... */ });
  // 6 tests that should be 1: "should load and display the payment details"
});
```

#### File Structure — One Top-Level `describe()`

```typescript
// GOOD — one top-level, nested groups
describe("Tenant Page", () => {
  beforeEach(() => { /* shared setup */ });

  describe("listing and search", () => {
    it("should display the table", async () => { /* ... */ });
    it("should search tenants", async () => { /* ... */ });
  });

  describe("CRUD operations", () => {
    it("should create a new tenant", async () => { /* ... */ });
    it("should edit an existing tenant", async () => { /* ... */ });
  });
});
```

```typescript
// BAD — multiple top-level describe blocks
describe("Tenant listing", () => { /* ... */ });
describe("Tenant update", () => { /* ... */ });
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

### Element Selection

**Preferred: Testing Library queries via `screenDom`**

```typescript
// By role (RECOMMENDED)
screenDom.getByRole("button", { name: "Submit" });
screenDom.getByRole("heading", { name: "Welcome", level: 1 });

// By label (form inputs)
screenDom.getByLabelText("Email Address");

// By text
screenDom.getByText("Success!");
screenDom.getByText(/welcome/i);

// By test ID
screenDom.getByTestId("user-card");

// Query variants
screenDom.getByRole("button");        // Throws if not found
screenDom.queryByRole("button");      // Returns null if not found
await screenDom.findByRole("button"); // Waits for element (async)
screenDom.getAllByRole("button");     // Returns array
```

**For modals/portals use `screenDomGlobal`:**

```typescript
import { screenDomGlobal } from "twd-js";
const modal = screenDomGlobal.getByRole("dialog");
```

**Fallback: CSS selectors via `twd.get()`**

```typescript
const button = await twd.get("button");
const byId = await twd.get("#email");
const multiple = await twd.getAll(".item");
```

### User Interactions

```typescript
const user = userEvent.setup();

await user.click(screenDom.getByRole("button", { name: "Save" }));
await user.type(screenDom.getByLabelText("Email"), "hello@example.com");
await user.dblClick(element);
await user.clear(input);
await user.selectOptions(select, "option-value");
await user.keyboard("{Enter}");

// With twd.get() elements — use .el for raw DOM
const twdButton = await twd.get(".save-btn");
await user.click(twdButton.el);
```

### Assertions

**Function style (any element):**

```typescript
twd.should(screenDom.getByRole("button"), "be.visible");
twd.should(screenDom.getByRole("button"), "have.text", "Submit");
twd.should(element, "contain.text", "partial");
twd.should(element, "have.class", "active");
twd.should(element, "have.attr", "type", "submit");
twd.should(element, "have.value", "test@example.com");
twd.should(element, "be.disabled");
twd.should(element, "be.checked");
twd.should(element, "not.be.visible");
```

**Method style (on twd elements):**

```typescript
const el = await twd.get("h1");
el.should("have.text", "Welcome");
el.should("be.visible");
```

**URL assertions:**

```typescript
await twd.url().should("eq", "http://localhost:3000/dashboard");
await twd.url().should("contain.url", "/dashboard");
```

**Chai expect (non-element assertions):**

```typescript
expect(array).to.have.length(3);
expect(value).to.equal("expected");
expect(obj).to.deep.equal({ key: "value" });
```

### Navigation and Waiting

```typescript
await twd.visit("/");
await twd.visit("/login");
await twd.wait(1000);                         // Wait for time (ms)
await twd.waitFor(() =>                       // Retry callback until it stops throwing
  screenDom.getByRole("heading", { name: /dashboard/i })
, { timeout: 2000, interval: 50, message: "heading to appear" });
await screenDom.findByText("Success!");        // Wait for element
await twd.notExists(".loading-spinner");       // Wait for element to NOT exist
```

> **Note**: `twd.visit()` uses the History API — it does NOT reload the page. See "State Management & Test Isolation" below for implications.

### waitFor vs twd.wait

| Aspect | `twd.waitFor(fn)` | `twd.wait(ms)` |
|--------|-------------------|----------------|
| Resolves when | Callback stops throwing | Fixed time elapses |
| Speed | As fast as the condition is met | Always waits full duration |
| Reliability | Adapts to timing variations | Fails if operation is slower |
| Use for | Race conditions — element exists but state isn't ready yet | Intentional delays (animations, debounce testing) |

**Do NOT add `waitFor` to every assertion.** Most TWD assertions work synchronously after `waitForRequest` or `findBy*` resolves. Only reach for `waitFor` when a test **fails** because of a genuine timing issue — the element is in the DOM but its state hasn't updated yet, or the element isn't in the DOM yet after a state change.

`waitFor` is generic — it returns the callback's resolved value, so you can extract a value and assert on it afterward. Keep one condition per callback. Do NOT put actions (like `userEvent.type`) inside — the callback retries from the top on each throw, causing side effects. A guard assertion + return value in the same callback is fine because both are reads.

**Good — targeted retry after a failure (return value pattern):**

```typescript
// Test failed: heading not in DOM yet after navigation → wrap in waitFor
const heading = await twd.waitFor(() => screenDom.getByRole("heading", { name: /dashboard/i }));
twd.should(heading, "be.visible");
```

**Good — retry until a value exists, then assert on its properties:**

```typescript
const event = await twd.waitFor(() => {
  const ev = findEvent("purchase");
  expect(ev).to.exist;
  return ev;
});
expect(event.customer_type).to.equal("b2c");
```

**Bad — wrapping everything "just in case":**

```typescript
// DON'T do this — waitForRequest already ensures data loaded
await twd.waitForRequest("getItems");
await twd.waitFor(() => screenDom.getByText("Item One")); // unnecessary
```

**Bad — putting actions inside the callback:**

```typescript
// DON'T do this — userEvent.type retries on each throw, typing again and again
await twd.waitFor(async () => {
  await userEvent.type(input, "hello");  // types again on every retry!
  expect(input).to.have.value("hello");
});
```

Full API reference: https://twd.dev/api/twd-commands.html#twd-waitfor-callback-options
Best practice guide: https://twd.dev/api/twd-commands.html#waitfor-vs-twd-wait

### State Management & Test Isolation

TWD runs tests directly in the browser **without page reloads**. The `twd.visit()` command simulates SPA navigation using the History API, which means your SPA router re-renders but **in-memory application state is preserved** between tests.

This is a deliberate trade-off: it keeps tests fast and deterministic, but it means state from tools like Zustand, Redux, Jotai, or plain module-level variables will **leak between tests** unless you explicitly reset it.

#### What TWD resets for you

TWD provides built-in reset methods for its own managed state:

```typescript
beforeEach(() => {
  twd.clearRequestMockRules();  // Clears API mock rules
  twd.clearComponentMocks();    // Clears component mocks
});
```

#### What you need to reset manually

Any state that lives in your application's JavaScript memory persists across tests:

| State type | Example | How to reset |
|---|---|---|
| State managers | Zustand, Redux, Jotai, Pinia | Call your store's reset method |
| Browser storage | localStorage, sessionStorage | `localStorage.clear()` |
| Module singletons | Caches, counters, flags | Re-assign to initial value |
| Global event listeners | `window.addEventListener(...)` | Remove in `afterEach` |
| Timers | `setInterval`, `setTimeout` | Clear in `afterEach` |

Most state management libraries provide a way to reset stores to their initial state. Expose a reset method on your stores and call it in `beforeEach`:

```typescript
import { resetMyStore } from "../../store";

describe("My feature", () => {
  beforeEach(() => {
    twd.clearRequestMockRules();
    twd.clearComponentMocks();
    resetMyStore();
    localStorage.clear();
  });

  it("should start with clean state", async () => {
    await twd.visit("/my-page");
    // State is fresh for every test
  });
});
```

#### Why not just reload the page?

TWD's test runner, sidebar UI, mock service worker, and all test definitions live in the same browser page as your app. A full page reload (`window.location.reload()`) would destroy the test runner itself, losing all test results and state. This is the fundamental constraint of in-browser testing — and the same trade-off other in-browser tools face.

### API Mocking

Always mock BEFORE `twd.visit()` or the action that triggers the request.

#### URL Matching — How It Works

> **Priority: use string URLs first, regex only as last resort.**

**1. String match (default, preferred)**

The `url` string is matched against the full request URL using boundary-aware substring matching. Valid boundaries after the match: end-of-string, `?`, `#`, `&`. If the match extends past the query string start, it's always valid.

| Rule `url` | Request URL | Matches? | Why |
|---|---|---|---|
| `/api/users` | `http://localhost/api/users` | Yes | End-of-string boundary |
| `/api/users` | `http://localhost/api/users?page=1` | Yes | `?` boundary |
| `/api/users` | `/api/users/123` | **No** | `/` is not a valid boundary — sub-paths are different resources |
| `/api/item` | `/api/items` | **No** | `s` is not a valid boundary — partial segments rejected |
| `/user` | `/username` | **No** | Same reason — partial segments rejected |
| `https://api.example.com/search?q=` | `https://api.example.com/search?q=friends` | Yes | Match extends past `?`, always valid |

Requests to URLs with file extensions (`.json`, `.js`, `.css`, `.html`, `.ts`, etc.) are automatically filtered out unless the rule URL also has a file extension.

```typescript
// Mock GET — string match handles path boundaries automatically
await twd.mockRequest("getUser", {
  method: "GET",
  url: "/api/user/123",
  response: { id: 123, name: "John Doe" },
  status: 200,
});

// For dynamic IDs, hardcode the mock value
await twd.mockRequest("getUser", {
  method: "GET",
  url: "/api/users/456",
  response: { id: 456, name: "Test User" },
});

// For external APIs with full domain
await twd.mockRequest("searchShows", {
  method: "GET",
  url: "https://api.tvmaze.com/search/shows?q=",
  response: [{ show: { name: "Friends" } }],
});
```

**2. Regex match (last resort)** — set `urlRegex: true`:
- Only use when the URL segment is truly unpredictable at mock time
- Invalid regex strings silently fail (no match, no throw)

```typescript
// RegExp literal
await twd.mockRequest("getUserById", {
  method: "GET",
  url: /\/api\/users\/\d+/,
  response: { id: 999, name: "Dynamic User" },
  urlRegex: true,
});

// String regex (starts with ^)
await twd.mockRequest("getUserById", {
  method: "GET",
  url: "^.*/api/users/\\d+",
  response: { id: 999, name: "Dynamic User" },
  urlRegex: true,
});
```

#### Other `mockRequest` patterns

```typescript
// Mock POST
await twd.mockRequest("createUser", {
  method: "POST",
  url: "/api/users",
  response: { id: 456, created: true },
  status: 201,
});

// Error responses
await twd.mockRequest("serverError", {
  method: "GET",
  url: "/api/data",
  response: { error: "Server error" },
  status: 500,
});

// Wait for request and inspect body
// IMPORTANT: rule.request IS the body — NOT rule.request.body
const rule = await twd.waitForRequest("submitForm");
expect(rule.request).to.deep.equal({ email: "test@example.com" });

// Wait for multiple requests
await twd.waitForRequests(["getUser", "getPosts"]);

// Check how many times a mock was hit (useful for debugging)
expect(twd.getRequestCount("getUser")).to.equal(2);

// Get hit counts for ALL mocks at once
const counts = twd.getRequestCounts();
// → { getUser: 2, getPosts: 1 }

// Clear all mocks AND reset counters (always in beforeEach)
twd.clearRequestMockRules();
```

### Component Mocking

> **Mock before visit**: Call `twd.mockComponent()` BEFORE `twd.visit()`, just like `mockRequest`. Use `.twd.test.tsx` extension when writing JSX in mock implementations.

```tsx
// In your component — wrap with MockedComponent
import { MockedComponent } from "twd-js/ui";

function Dashboard() {
  return (
    <MockedComponent name="ExpensiveChart">
      <ExpensiveChart data={data} />
    </MockedComponent>
  );
}
```

```tsx
// In your test — mock BEFORE twd.visit()
twd.mockComponent("ExpensiveChart", () => (
  <div data-testid="mock-chart">Mocked Chart</div>
));
await twd.visit("/dashboard");

// Clear in beforeEach (already included in standard beforeEach)
twd.clearComponentMocks();
```

### Module Stubbing with Sinon

> **Sinon is a separate npm package** — install it with `npm install -D sinon`. Import as `import Sinon from "sinon"`. NEVER import from `twd-js/sinon` — that path does NOT exist.

ESM named exports are IMMUTABLE. Wrap hooks/services in objects with default export:

```typescript
// hooks/useAuth.ts — CORRECT: stubbable
const useAuth = () => useAuth0();
export default { useAuth };
```

```typescript
// In test:
import Sinon from "sinon"; // npm package "sinon", NOT "twd-js/sinon"
import authModule from "../hooks/useAuth";

Sinon.stub(authModule, "useAuth").returns({
  isAuthenticated: true,
  user: { name: "John" },
});
// Always Sinon.restore() in beforeEach
```

#### Stubbable Gate Pattern

**Test what you own, not what you don't own.** Instead of mocking third-party provider internals (Auth0, MSAL, ConfigCat, etc.), create a stubbable boolean gate that skips the provider entirely in tests:

```typescript
// gates/enableAuth.ts — gate module
const enableAuth = () => true;
export default { enableAuth };
```

```typescript
// main.tsx — conditionally mount provider
import enableAuthModule from "./gates/enableAuth";

if (enableAuthModule.enableAuth()) {
  // mount <MsalProvider>, <Auth0Provider>, etc.
  renderApp(<AuthProvider><App /></AuthProvider>);
} else {
  renderApp(<App />);
}
```

```typescript
// In test — skip the auth provider entirely
import Sinon from "sinon";
import enableAuthModule from "../gates/enableAuth";

Sinon.stub(enableAuthModule, "enableAuth").returns(false);
await twd.visit("/");
// App renders without auth provider — no hook-count mismatches
```

This works for any third-party provider (feature flags, analytics, auth). It avoids hook-count mismatches and complex provider mocking — you test your app's behavior, not the library's internals.

### Extended CRUD Template

A complete flow-based test covering list → create → edit → delete:

```typescript
import { twd, userEvent, screenDom, expect } from "twd-js";
import { describe, it, beforeEach } from "twd-js/runner";

const mockItems = [
  { id: 1, name: "Item One", email: "one@test.com" },
  { id: 2, name: "Item Two", email: "two@test.com" },
];

describe("Items Page", () => {
  beforeEach(() => {
    twd.clearRequestMockRules();
    twd.clearComponentMocks();
    // Reset app state if needed — see "State Management & Test Isolation" below
  });

  describe("listing", () => {
    it("should display all items in the table", async () => {
      await twd.mockRequest("getItems", {
        method: "GET",
        url: "/api/items",
        response: mockItems,
        status: 200,
      });

      await twd.visit("/items");
      await twd.waitForRequest("getItems");

      const rows = screenDom.getAllByRole("row");
      // +1 for header row
      expect(rows).to.have.length(mockItems.length + 1);
      twd.should(screenDom.getByText("Item One"), "be.visible");
    });
  });

  describe("create flow", () => {
    it("should open form, fill fields, and submit", async () => {
      await twd.mockRequest("getItems", {
        method: "GET",
        url: "/api/items",
        response: mockItems,
        status: 200,
      });
      await twd.mockRequest("createItem", {
        method: "POST",
        url: "/api/items",
        response: { id: 3, name: "New Item", email: "new@test.com" },
        status: 201,
      });

      await twd.visit("/items");
      await twd.waitForRequest("getItems");

      // Open the create form
      const user = userEvent.setup();
      await user.click(screenDom.getByRole("button", { name: /add/i }));

      // Fill the form
      await user.type(screenDom.getByLabelText(/name/i), "New Item");
      await user.type(screenDom.getByLabelText(/email/i), "new@test.com");

      // Submit
      await user.click(screenDom.getByRole("button", { name: /save/i }));
      await twd.waitForRequest("createItem");

      // Verify the POST body (rule.request IS the body — NOT rule.request.body)
      const rule = await twd.waitForRequest("createItem");
      expect(rule.request).to.deep.equal({
        name: "New Item",
        email: "new@test.com",
      });
    });
  });

  describe("error states", () => {
    it("should show error message on server failure", async () => {
      await twd.mockRequest("getItems", {
        method: "GET",
        url: "/api/items",
        response: { error: "Internal Server Error" },
        status: 500,
      });

      await twd.visit("/items");
      await twd.waitForRequest("getItems");

      twd.should(screenDom.getByText(/error/i), "be.visible");
    });
  });
});
```

### Common Mistakes to AVOID

1. **Forgetting `await`** on `twd.get()`, `userEvent.*`, `twd.visit()`, `screenDom.findBy*`, `twd.waitFor()`, **`twd.mockRequest()`**
2. **Mocking AFTER visit** — always mock before `twd.visit()`
3. **Not clearing mocks** — always `twd.clearRequestMockRules()` and `twd.clearComponentMocks()` in `beforeEach`
4. **Using Node.js APIs** — tests run in the browser, no `fs`, `path`, etc.
5. **Importing from wrong package** — `describe`/`it`/`beforeEach` from `twd-js/runner`, `expect` from `twd-js`, NOT Jest/Mocha
6. **Stubbing named exports** — ESM makes them immutable. Use the default-export object pattern
7. **Writing granular unit tests** — don't write one `it()` per element. Test full user flows. Aim for **3–6 tests per feature** (see "Testing Philosophy" above). Anti-patterns: one `it()` per UI element (`"should display label"`, `"should display button"`), separate tests for checks that share the same setup. If 10+ tests cover a single page, combine them
8. **Multiple top-level `describe()` blocks** — always use ONE top-level `describe()` per file with nested groups
9. **Jest-style assertions** — use `expect(x).to.equal(y)` NOT `.toBe(y)`, use `.to.have.length(n)` NOT `.toHaveLength(n)`. TWD uses Chai, not Jest
10. **Using `body` instead of `response`** in `mockRequest` — the config key is `response`, not `body`
11. **Wrapping `response` in `JSON.stringify` unnecessarily** — `response` accepts any value directly; only use `JSON.stringify` if the actual API returns a stringified JSON body
12. **Positional args in `mockRequest`** — always use the alias + config object pattern: `await twd.mockRequest("alias", { method, url, response, status })`
13. **Importing Sinon from `twd-js/sinon`** — Sinon is a standalone npm package. Import as `import Sinon from "sinon"`, NEVER from `twd-js/sinon` or any `twd-js/*` subpath
14. **Mocking components AFTER visit** — call `twd.mockComponent()` BEFORE `twd.visit()`, same rule as `mockRequest`
15. **Not resetting app state between tests** — TWD runs without page reloads, so store state, localStorage, and module singletons persist. Always reset in `beforeEach`
16. **Using regex when string match suffices** — string matching is boundary-aware: `/api/users` won't match `/api/users/123` or `/api/items`. For dynamic IDs, hardcode the mock value (e.g., `url: "/api/users/456"`). Only use `urlRegex: true` when the segment is truly unpredictable at mock time
17. **Using `rule.request.body` instead of `rule.request`** — `waitForRequest` returns a rule where `.request` IS the parsed body directly. Writing `rule.request.body.X` throws `Cannot read properties of undefined`. Correct: `expect(rule.request).to.deep.equal({ ... })`
18. **Using `it.only()` to isolate tests** — use `npx twd-relay run --test "name"` instead, which doesn't require editing the test file and avoids the risk of forgetting to remove `it.only()`
