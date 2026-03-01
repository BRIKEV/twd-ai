# TWD Setup Reference

<!-- Package provenance: twd-js (npm: brikev, MIT, github.com/BRIKEV/twd),
     twd-relay (npm: brikev, MIT, github.com/BRIKEV/twd-relay).
     All TWD code is dev-only (import.meta.env.DEV guard). -->

## Step 1: Install Packages

```bash
npm install twd-js
npm install --save-dev twd-relay
```

## Step 2: Initialize Mock Service Worker

```bash
npx twd-js init public --save
```

This copies `mock-sw.js` to the `public/` directory. If the public directory has a different name (e.g., `static/`), use that path instead.

## Step 3: Configure Entry Point

TWD should only load in development mode.

### Bundled Setup (Recommended — all frameworks)

```typescript
// src/main.ts (or main.tsx)
if (import.meta.env.DEV) {
  const { initTWD } = await import('twd-js/bundled');
  const tests = import.meta.glob("./**/*.twd.test.ts");

  initTWD(tests, {
    open: true,
    position: 'left',
    serviceWorker: true,
    serviceWorkerUrl: '/mock-sw.js',
  });

  // Connect twd-relay browser client
  if (import.meta.env.VITE_ENABLE_TWD_RELAY === 'true') {
    const { createBrowserClient } = await import('twd-relay/browser');
    const client = createBrowserClient({ url: `${window.location.origin}/__twd/ws` });
    client.connect();
  }
}
```

**initTWD options:**
- `open` (boolean) — sidebar open by default. Default: `true`
- `position` (`"left"` | `"right"`) — sidebar position. Default: `"left"`
- `serviceWorker` (boolean) — enable API mocking. Default: `true`
- `serviceWorkerUrl` (string) — service worker path. Default: `'/mock-sw.js'`

> **Note**: If your project has a custom Vite `base` path (e.g., `/my-app/`), adjust the `serviceWorkerUrl` accordingly: `serviceWorkerUrl: '/my-app/mock-sw.js'`.
> Also adjust the relay client URL: `` `${window.location.origin}/my-app/__twd/ws` ``.

### Framework-Specific Notes

**Vue:**
```typescript
// src/main.ts
import { createApp } from 'vue';
import App from './App.vue';

if (import.meta.env.DEV) {
  const { initTWD } = await import('twd-js/bundled');
  const tests = import.meta.glob("./**/*.twd.test.ts");
  initTWD(tests, { open: true, position: 'left' });

  if (import.meta.env.VITE_ENABLE_TWD_RELAY === 'true') {
    const { createBrowserClient } = await import('twd-relay/browser');
    const client = createBrowserClient({ url: `${window.location.origin}/__twd/ws` });
    client.connect();
  }
}

createApp(App).mount('#app');
```

**Angular:**
```typescript
// src/main.ts
import { isDevMode } from '@angular/core';

if (isDevMode()) {
  const { initTWD } = await import('twd-js/bundled');
  // Angular may not support import.meta.glob — define tests manually:
  const tests = {
    './twd-tests/feature.twd.test.ts': () => import('./twd-tests/feature.twd.test'),
  };
  initTWD(tests, { open: true, position: 'left' });

  // @ts-ignore — VITE_ENABLE_TWD_RELAY may not exist in Angular env types
  if (import.meta.env?.VITE_ENABLE_TWD_RELAY === 'true') {
    const { createBrowserClient } = await import('twd-relay/browser');
    const client = createBrowserClient({ url: `${window.location.origin}/__twd/ws` });
    client.connect();
  }
}
```

**Solid.js:**
```tsx
// src/main.tsx
if (import.meta.env.DEV) {
  const { initTWD } = await import('twd-js/bundled');
  const tests = import.meta.glob("./**/*.twd.test.ts");
  initTWD(tests, { open: true, position: 'left' });

  if (import.meta.env.VITE_ENABLE_TWD_RELAY === 'true') {
    const { createBrowserClient } = await import('twd-relay/browser');
    const client = createBrowserClient({ url: `${window.location.origin}/__twd/ws` });
    client.connect();
  }
}
```

## Step 4: Vite Plugins

```typescript
// vite.config.ts
import { twdHmr } from 'twd-js/vite-plugin';
import { twdRemote } from 'twd-relay/vite';
import type { PluginOption } from 'vite';

export default defineConfig({
  plugins: [
    // ... other plugins
    twdHmr(),
    twdRemote() as PluginOption,
  ],
});
```

## Step 5: Write a First Test

Create a `src/twd-tests/` folder for all TWD tests. For larger projects, organize by domain (e.g., `src/twd-tests/auth/`, `src/twd-tests/dashboard/`).

```typescript
// src/twd-tests/app.twd.test.ts
import { twd, screenDom } from "twd-js";
import { describe, it } from "twd-js/runner";

describe("App", () => {
  it("should render the main heading", async () => {
    await twd.visit("/");
    const heading = screenDom.getByRole("heading", { level: 1 });
    twd.should(heading, "be.visible");
  });
});
```

**Folder structure example:**
```
src/twd-tests/
  app.twd.test.ts          # General app tests
  auth/
    login.twd.test.ts      # Auth-related tests
  dashboard/
    overview.twd.test.ts   # Dashboard domain tests
  mocks/
    users.ts               # Shared mock data
```

## Verify Setup

Use the relay command from your `.claude/twd-patterns.md` (or defaults):

```bash
# Default (works with Vite default port 5173 and base path /)
npx twd-relay run

# Custom port/base path
npx twd-relay run --port PORT --path "BASE/__twd/ws"
```

If exit code is 0 and the test passes, setup is complete.
