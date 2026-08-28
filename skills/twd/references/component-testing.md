# TWD Test Writing — Component Testing with Testing Library

Testing Library's `render()` works inside a TWD test. The component mounts into the running app in a real browser, so the same Testing Library API you already know runs against a real DOM instead of jsdom.

**Flow tests remain the default.** Read this only when a component genuinely is the subject of the test and driving it through the app would need disproportionate scaffolding. See "When to reach for this" below before writing one.

For the core test-writing API (mockRequest, assertions, waitFor, state isolation, Sinon stubbing), see `test-writing.md`. For replacing a component with a stub, which is a different thing entirely, see `test-advanced.md`.

## When to reach for this

Use a **component test** only when BOTH are true:

1. The component itself is what the test is about: a form's validation states, a dialog that opens and closes, a table that sorts.
2. Reaching that behaviour through a normal flow test would mean navigating several screens or building fixtures that have nothing to do with what you are asserting.

Use a **flow test** (the default) for anything that crosses a boundary: routing, data loading, a sequence of screens, state that survives a navigation.

Rendering a component in isolation to test a flow means rebuilding the app around it, which is how test files end up longer than the components they test. When in doubt, write the flow test.

The anti-granularity rules in `test-writing.md` still apply here. A component test is not a licence to write one `it()` per element. Each `it()` still covers a meaningful behaviour with multiple assertions.

## Setup requirements

### 1. Testing Library must be installed

TWD does not ship framework renderers. The project needs its own dev dependency:

```bash
npm install --save-dev @testing-library/react
```

If it is absent, say so and stop. Do not add it without the user's go-ahead.

### 2. The test file pattern must match `.tsx`

Component tests are `.tsx`. The `twd()` plugin's default `testFilePattern` is `'/**/*.twd.test.ts'`, which matches `.ts` ONLY. A `.tsx` file is skipped **silently**: no error, no warning, and the test never appears in the sidebar.

Check `vite.config.ts` before writing a `.tsx` test. It must have:

```ts
twd({ testFilePattern: '/**/*.twd.test.{ts,tsx}' })
```

If it does not, fix it first, or every test you write will be invisible.

### 3. Vitest must not collect TWD tests

If the project also runs Vitest, it matches `*.test.tsx` by default, collects the TWD files, finds no `describe` it recognises, and fails the run with `No test suite found in file`:

```ts
test: {
  exclude: [...configDefaults.exclude, '**/*.twd.test.*'],
},
```

### 4. `cleanup()` in `beforeEach` (required)

`render()` appends to the document and removes nothing on its own. In jsdom the environment is torn down between files. In a real browser it is not, so renders stack up and queries start finding duplicates.

```tsx
import { cleanup } from "@testing-library/react";

beforeEach(() => {
  cleanup();
  twd.clearRequestMockRules();
});
```

### 5. A blank route to render into (recommended)

Optional, but worth having. With `cleanup()` in place renders no longer stack up, so it is not required. It still helps: mounting a component on top of a page that already renders it makes queries find two of everything and Testing Library throws.

The idea is framework-neutral. The router needs one route that renders nothing, and the suite visits it once before rendering.

```tsx
// React Router
<Route path="testing-library" element={<div />} />
```

```ts
await twd.visit("/testing-library");
```

## Queries: use `screen`, NOT `screenDom`

This is the trap that wastes the most time.

`render()` mounts into a fresh `div` appended to `document.body`, which is **outside** the app root that `screenDom` scopes to. `screenDom` queries will fail to find your component.

Everywhere else in TWD, `screenDom` is the right default because it excludes the sidebar. Component tests are the exception.

```ts
// Works — render() mounted into document.body
screen.getByText("Add Item");
screenDomGlobal.getByRole("button", { name: "Add Item" });

// Does NOT work — scoped to the app root, which is not where render() mounted
screenDom.getByText("Add Item");
```

Prefer Testing Library's own `screen`. `screenDomGlobal` also works, but it can match elements inside the TWD sidebar, so keep those queries specific.

## Mock at boundaries you do not own

`twd.mockRequest` is still the right tool and still works. It replaces the network, which is a boundary you do not own, and everything on your side of it still runs: component, hook, provider, router.

```ts
await twd.mockRequest("createCar", {
  url: "/api/cars",
  method: "POST",
  status: 201,
  response: { id: "test-1", model: "Golf" },
});
```

**Use the real providers.** Do NOT stub a hook, a context, or a component out of the project's own `src/` just to get the component to render. That stub sits between the assertion and the behaviour under test, and the test starts checking your description of the code instead of the code.

## Full example

```tsx
import { render, screen, cleanup } from "@testing-library/react";
import { describe, it, beforeEach } from "twd-js/runner";
import { twd, userEvent } from "twd-js";
import { AppProvider } from "@/context/AppContext";
import { Add } from "../Add";

describe("Add Component", () => {
  beforeEach(() => {
    cleanup();
    twd.clearRequestMockRules();
  });

  it("should open the dialog, fill the form, and submit", async () => {
    await twd.mockRequest("createCar", {
      url: "/api/cars",
      method: "POST",
      status: 201,
      response: { id: "test-1", model: "Golf" },
    });

    await twd.visit("/testing-library");
    render(<AppProvider><Add /></AppProvider>);

    twd.should(screen.getByText("Add Item"), "be.visible");

    await userEvent.click(screen.getByText("Add Item"));
    await userEvent.type(await screen.findByPlaceholderText("Enter model"), "Golf");

    twd.should(screen.getByPlaceholderText("Enter model"), "have.value", "Golf");

    await userEvent.click(screen.getByText("Save"));
    await twd.waitForRequest("createCar");
  });
});
```

`AppProvider` here is the real provider, not a test double. `twd.should` accepts any element you hand it, whether a query found it in the app or in a component you just rendered.

## Framework support

`@testing-library/react` is the verified path and the one these examples use.

The same approach is expected to work with `@testing-library/vue` and `@testing-library/solid`, since Testing Library was never tied to jsdom, but this has not been verified. Do not assume it works for a framework the project has not already proven. Make no claim about Angular, whose `TestBed` is a different problem inside a running dev server.

## Common mistakes to AVOID

### DON'T: use `screenDom` for a rendered component

```tsx
render(<Add />);
screenDom.getByText("Add Item");  // fails — render() mounts outside the app root
```

Use `screen` or `screenDomGlobal`.

### DON'T: forget `cleanup()`

Without it, renders accumulate across tests and queries throw "found multiple elements".

### DON'T: write a `.tsx` test without checking `testFilePattern`

The default is `.ts` only. The test will never run, and nothing will tell you.

### DON'T: stub the project's own hooks or context

```tsx
// BAD — the stub is inside the thing under test
sinon.stub(useAddModule, "useAdd").returns({ ... });
render(<Add />);
```

Use the real provider and mock the network instead.

### DON'T: reach for a component test to cover a flow

If the test involves routing, loading data across screens, or state surviving navigation, it is a flow test. Write it as one.
