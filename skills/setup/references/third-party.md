# Third-Party Code

Read from `/twd:setup` only when Step 1 item 14 found `<MockedComponent name=` hits or the user answered yes to Step 2 Batch 2 #3. "Test what you own, mock what you don't."

## Component or module

Ask for each item the user names:

- **Component** — renders UI (map, payment form, camera, video player) → component mocking. It is wrapped in `<MockedComponent name="...">` from `twd-js/ui`, and a test registers `twd.mockComponent(name, Fake)` **before** `twd.visit()`. No Sinon. Hits from Step 1 item 14 are already wrapped: list them as handled.
- **Module** — a hook or function (`useAuth`, an analytics client) → Sinon stub.

## `twd-patterns.md` sections

Write the section for each kind present; omit the other.

```markdown
## Third-Party Components

These components are wrapped in `<MockedComponent name="...">` (from `twd-js/ui`) and replaced in tests with `twd.mockComponent(name, Fake)`, registered **before** `twd.visit()`:

| Component | Package | Mock name | Where |
|-----------|---------|-----------|-------|
| COMPONENT | `package` | `MOCK_NAME` | `src/path/File.tsx` |

The fake receives the wrapped child's props (callbacks like `onSuccess`, `onChange`). See the twd skill's `test-advanced.md`.

## Third-Party Modules

These external modules should be stubbed in tests:

| Module | Import Pattern | Stub Strategy |
|--------|---------------|---------------|
| MODULE_NAME | `import { hook } from 'package'` | `Sinon.stub(moduleObj, 'hook').returns(...)` |

See the twd skill's `test-api.md` ("Module Stubbing with Sinon") for the default-export object pattern required for ESM stubbing.
```

## `beforeEach`

Components need nothing extra: `twd.clearComponentMocks()` is already there. Modules only:

```typescript
Sinon.restore();
Sinon.stub(authModule, "useAuth").returns(/* ... */);
```

The setup scaffold gets `Sinon.restore()` only when a module was configured.
