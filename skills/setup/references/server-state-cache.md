# Server-State Cache Reset

Read by `/twd:setup` only when Step 1 detected a server-state cache library.

## The reset line per library

Substitute `QUERY_CACHE_RESET` in the `beforeEach` template with the right line:

| Library | Import + reset line |
|---|---|
| TanStack Query (any framework) | `import { queryClient } from "USER_PATH";` + `queryClient.clear();` |
| React Query v3 | same as TanStack Query |
| SWR (global cache) | `import { mutate } from "swr";` + `mutate(() => true, undefined, { revalidate: false });` |
| SWR (`<SWRConfig provider={...}>`) | Export the provider Map as a singleton at `USER_PATH` and call `.clear()` on it |
| Apollo Client | `import { apolloClient } from "USER_PATH";` + `await apolloClient.clearStore();` (the `beforeEach` becomes `async`) |
| RTK Query | `import { store } from "USER_PATH";` + `store.dispatch(api.util.resetApiState());` |
| urql | Use `cache.invalidate("Query")` via `@urql/exchange-graphcache` if installed; otherwise document the limitation (urql has no cross-version reset primitive) |

## Scaffolding the singleton

Only when the user picked "Generate the pattern for me".

Two changes are needed:
- **Create the singleton file** at `src/<lib>-client.ts` (or `.js` if the project is JS-only).
- **Refactor the entry file** (or wherever the client is currently constructed) to import the singleton instead of `new`ing it inline.

Show the diff to the user via `Edit` and confirm before applying. Templates per library:

**TanStack Query (React; Vue/Solid/Angular are analogous — swap the import package):**

```typescript
// src/query-client.ts
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 1000 * 30 } },
});
```

Entry-file refactor: replace `const queryClient = new QueryClient(...)` with `import { queryClient } from './query-client'`. The `<QueryClientProvider client={queryClient}>` stays where it is.

**Apollo Client:**

```typescript
// src/apollo-client.ts
import { ApolloClient, InMemoryCache } from '@apollo/client';

export const apolloClient = new ApolloClient({
  uri: '/graphql',
  cache: new InMemoryCache(),
});
```

Entry-file refactor: replace inline `new ApolloClient(...)` with `import { apolloClient } from './apollo-client'`.

**SWR (global cache):** no singleton extraction needed — SWR's cache is global by default and reset via `mutate(() => true, undefined, { revalidate: false })`. Skip the scaffold step but still write the heads-up section.

**SWR (`<SWRConfig provider={...}>`):**

```typescript
// src/swr-cache.ts
export const swrCache = new Map();
```

Then in the entry file, pass `provider={() => swrCache}` to `<SWRConfig>` and reset via `swrCache.clear()`.

**RTK Query:** no separate singleton needed — the store is already a singleton. Just confirm the store's export path and reset via `store.dispatch(api.util.resetApiState())`.

**urql:** if `@urql/exchange-graphcache` is in use, document the `cache.invalidate("Query")` pattern in `twd-patterns.md`. If not, surface the limitation to the user and offer to skip the QUERY_CACHE_RESET line — there's no general-purpose urql cache reset.

After scaffolding, update `USER_PATH` in the generated `twd-patterns.md` to point at the new singleton file (e.g. `./query-client`).
