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

### 4. The component host helper (required)

`render()` appends its container to `document.body`, after the app root, and the app's own DOM stays on the page, so `screen` matches the app's elements as well as the ones the test rendered. One helper solves both without touching the app. Create it once per project, next to the tests:

```ts
// src/twd-tests/support/componentHost.ts
const HOST_ID = 'twd-component-host';
const APP_ROOT_ID = 'root'; // 'app' in a default Vue app

let appRoot: HTMLElement | null = null;
let placeholder: Comment | null = null;

/** The element component tests render into: a blank div on an empty page. */
export function componentHost(): HTMLElement {
  detachApp();

  let host = document.getElementById(HOST_ID);
  if (!host) {
    host = document.createElement('div');
    host.id = HOST_ID;
  }
  if (!host.isConnected) {
    document.body.prepend(host);
  }

  host.innerHTML = '';
  return host;
}

/** Removes the host and puts the app back. Call it in afterEach. */
export function restorePage(): void {
  document.getElementById(HOST_ID)?.remove();
  attachApp();
}

function detachApp(): void {
  if (placeholder) return;

  const root = document.getElementById(APP_ROOT_ID);
  if (!root) return;

  appRoot = root;
  placeholder = document.createComment(' app detached by twd component test ');
  root.replaceWith(placeholder);
}

function attachApp(): void {
  if (!placeholder || !appRoot) return;

  placeholder.replaceWith(appRoot);
  placeholder = null;
  appRoot = null;
}
```

Set `APP_ROOT_ID` to the id of the element the app mounts into (read `index.html`). Two details matter, so do not "simplify" them:

- **Detach the app root, never empty it.** `root.innerHTML = ''` pulls the DOM out from under the framework while it still holds references to those nodes, and the app does not come back. Moving the node out and putting it back keeps those references, so `restorePage()` returns a live app.
- **Prepend the host, do not append it.** That puts the component at the top of the page and inside the offset TWD applies for its sidebar.

Pass the host as the `container`: `render(<Add />, { container: componentHost() })`. No route and no `twd.visit()` are needed.

### 5. `cleanup()` and `restorePage()` in `afterEach` (required)

`render()` removes nothing on its own. In jsdom the environment is torn down between files; in a real browser it is not, so renders stack up and queries start finding duplicates. And without `restorePage()` the app root is never put back, so every flow test after the component tests sees a blank page.

```tsx
import { cleanup } from "@testing-library/react";
import { afterEach } from "twd-js/runner";
import { restorePage } from "./support/componentHost";

afterEach(() => {
  cleanup();
  restorePage();
});
```

Use `afterEach`, not `beforeEach`: TWD runs after-hooks in a `finally`, so they run even when the test fails, and the app is back before the next flow test needs it. `twd.clearRequestMockRules()` stays in `beforeEach` as usual.

## Queries: use `screen`, NOT `screenDom`

This is the trap that wastes the most time.

`render()` mounts into the component host, which sits **outside** the app root that `screenDom` scopes to (and the app root is detached while the test runs). `screenDom` queries will fail to find your component.

Everywhere else in TWD, `screenDom` is the right default because it excludes the sidebar. Component tests are the exception.

```ts
// Works — render() mounted into the component host
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
import { describe, it, beforeEach, afterEach } from "twd-js/runner";
import { twd, userEvent } from "twd-js";
import { AppProvider } from "@/context/AppContext";
import { Add } from "../Add";
import { componentHost, restorePage } from "./support/componentHost";

describe("Add Component", () => {
  beforeEach(() => {
    twd.clearRequestMockRules();
  });

  afterEach(() => {
    cleanup();
    restorePage();
  });

  it("should open the dialog, fill the form, and submit", async () => {
    await twd.mockRequest("createCar", {
      url: "/api/cars",
      method: "POST",
      status: 201,
      response: { id: "test-1", model: "Golf" },
    });

    render(<AppProvider><Add /></AppProvider>, { container: componentHost() });

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

The same approach is expected to work with `@testing-library/vue` and `@testing-library/solid`: both take the same `container` option, so the helper transfers with `APP_ROOT_ID` set to the app's mount element (`'app'` in a default Vue app). This has not been verified. Do not assume it works for a framework the project has not already proven. Make no claim about Angular: `@testing-library/angular` mounts through `TestBed` and takes no `container`, so the helper does not apply.

## Common mistakes to AVOID

### DON'T: use `screenDom` for a rendered component

```tsx
render(<Add />);
screenDom.getByText("Add Item");  // fails — render() mounts outside the app root
```

Use `screen` or `screenDomGlobal`.

### DON'T: render without the component host

```tsx
render(<Add />);  // appended after the app — queries find two of everything
```

Pass `{ container: componentHost() }`.

### DON'T: forget `cleanup()` and `restorePage()` in `afterEach`

Without `cleanup()`, renders accumulate across tests and queries throw "found multiple elements". Without `restorePage()`, the app root stays detached and every flow test after this file sees a blank page. Put both in `afterEach`, not `beforeEach`.

### DON'T: empty the app root instead of detaching it

`document.getElementById('root').innerHTML = ''` leaves the framework holding dead nodes and the app never comes back. The helper moves the node out and puts it back.

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
