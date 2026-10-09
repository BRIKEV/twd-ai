# TWD Test API — Detail

Read on demand from `test-writing.md`, which has the core. This file has the full surface: mock options and URL matching, waiting, every interaction and assertion, and module stubbing.

## API Mocking

### Full `mockRequest` Options

```typescript
await twd.mockRequest("alias", {
  method: string,              // HTTP method (GET, POST, PUT, DELETE, etc.)
  url: string | RegExp,        // URL to match
  response: unknown,           // Response body (any JSON-serializable value)
  status?: number,             // HTTP status code (default: 200); 0 simulates a network failure
  responseHeaders?: Record<string, string>, // Response headers — NOT `headers`, which is silently ignored
  delay?: number,              // Delays the response only, in ms
  urlRegex?: boolean,          // Enable regex matching for url (default: false)
});
```

- **`delay` holds the response, not the request.** The app sees the request leave at once, so `twd.waitForRequest()` resolves immediately. Use it to assert a loading state, then wait for what the response renders (`findBy*` or `twd.notExists(".spinner")`).
- **`status: 0`** makes the request fail as a network error — the app's `fetch` rejects instead of resolving with an error status. Use it to test offline or connection-lost handling; use `500` for a server error.

### URL Matching — How It Works

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

### Other `mockRequest` patterns

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

// Wait on the same request twice: re-register the alias in between. That
// replaces the rule and resets its executed flag; without it the second
// waitForRequest resolves at once on the first hit.
const refresh = await screenDom.findByRole("button", { name: "Refresh" });
await userEvent.click(refresh);
await twd.waitForRequest("getUser");      // first request
await twd.mockRequest("getUser", { method: "GET", url: "/api/user", response: { id: 1, name: "John" } });
await userEvent.click(refresh);
await twd.waitForRequest("getUser");      // waits for the second one

// Check how many times a mock was hit (useful for debugging)
expect(twd.getRequestCount("getUser")).to.equal(2);

// Get hit counts for ALL mocks at once
const counts = twd.getRequestCounts();
// → { getUser: 2, getPosts: 1 }

// Clear all mocks AND reset counters (always in beforeEach)
twd.clearRequestMockRules();
```

## Element Selection

**Preferred: Testing Library `findBy*` queries via `screenDom`**

```typescript
// By role (RECOMMENDED)
await screenDom.findByRole("button", { name: "Submit" });
await screenDom.findByRole("heading", { name: "Welcome", level: 1 });

// By label (form inputs)
await screenDom.findByLabelText("Email Address");

// By text
await screenDom.findByText("Success!");
await screenDom.findByText(/welcome/i);

// By test ID
await screenDom.findByTestId("user-card");

// Query variants, in order of preference
await screenDom.findByRole("button");     // Waits for the element — the default
await screenDom.findAllByRole("button");  // Waits, returns array — the default for lists
screenDom.getByRole("button");            // Throws at once — only when already rendered
screenDom.queryByRole("button");          // Returns null — only to assert absence
```

`findBy*` waits up to 3000 ms in TWD.

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

## User Interactions

```typescript
const user = userEvent.setup();

await user.click(screenDom.getByRole("button", { name: "Save" }));
await user.type(screenDom.getByLabelText("Email"), "hello@example.com");
await user.dblClick(element);
await user.clear(input);
await user.selectOptions(select, "option-value");
await user.keyboard("{Enter}");
await user.tab();                                  // move focus to the next element
await user.hover(menuTrigger);                     // tooltips, hover menus
await user.unhover(menuTrigger);
await user.upload(fileInput, new File(["a,b"], "data.csv", { type: "text/csv" }));

// With twd.get() elements — use .el for raw DOM
const twdButton = await twd.get(".save-btn");
await user.click(twdButton.el);
```

**Range, date, time and color inputs — `twd.setInputValue`.** userEvent cannot drive a slider or a native picker. `twd.setInputValue` sets the value and dispatches the input event the framework listens for. It is synchronous. Use it ONLY for these input types — text inputs, textareas and checkboxes go through userEvent, which fires the real keystroke and click events:

```typescript
twd.setInputValue(await screenDom.findByLabelText("Volume"), "75");     // type="range"
twd.setInputValue(await screenDom.findByLabelText("Start"), "13:30");   // type="time"
twd.setInputValue(await screenDom.findByLabelText("Due"), "2026-12-01"); // type="date"
```

## Assertions

**Function style (any element):**

```typescript
twd.should(screenDom.getByRole("button"), "be.visible");
twd.should(screenDom.getByRole("button"), "have.text", "Submit");
twd.should(element, "contain.text", "partial");
twd.should(element, "have.class", "active");
twd.should(element, "have.attr", "type", "submit");
twd.should(element, "have.value", "test@example.com");
twd.should(element, "be.disabled");
twd.should(element, "be.enabled");
twd.should(element, "be.checked");
twd.should(option, "be.selected");     // <option> elements
twd.should(input, "be.focused");       // focus moved here (after tab, autofocus, a validation error)
twd.should(element, "be.empty");       // no text content
twd.should(element, "be.hidden");      // in the DOM but not shown
twd.should(element, "not.be.visible");
```

Every assertion takes a `not.` prefix. `be.hidden` is for an element that stays in the DOM (a collapsed panel, a closed `<details>`); for one that is removed, use `screenDom.queryBy*` → `expect(...).to.be.null` or `await twd.notExists(selector)`.

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

## Navigation and Waiting

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

> **Note**: `twd.visit()` uses the History API — it does NOT reload the page. See "State Isolation" in `test-writing.md` for what that means for app state.

## waitFor vs twd.wait

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

## Module Stubbing with Sinon

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

### Stubbable Gate Pattern

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

