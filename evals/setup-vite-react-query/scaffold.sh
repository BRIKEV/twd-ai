#!/usr/bin/env bash
# The common case: a Vite + React app with TanStack Query and no TWD yet. The
# query client is already a module singleton, so the cache reset has a path.
set -euo pipefail
mkdir -p src/api public
git init -q -b main . 2>/dev/null || true
cat > package.json <<'EOF'
{
  "name": "todo-app",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "build": "tsc -b && vite build" },
  "dependencies": {
    "@tanstack/react-query": "^5.90.0", "react": "^19.1.0", "react-dom": "^19.1.0"
  },
  "devDependencies": { "@vitejs/plugin-react": "^5.0.0", "typescript": "~5.9.0", "vite": "^7.1.0" }
}
EOF
cat > vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
});
EOF
echo '{ "files": [], "references": [{ "path": "./tsconfig.app.json" }] }' > tsconfig.json
echo '{ "compilerOptions": { "strict": true, "jsx": "react-jsx", "noEmit": true }, "include": ["src"] }' > tsconfig.app.json
cat > index.html <<'EOF'
<!doctype html>
<html><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
EOF
cat > src/query-client.ts <<'EOF'
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient();
EOF
cat > src/main.tsx <<'EOF'
import { createRoot } from 'react-dom/client';
import { QueryClientProvider } from '@tanstack/react-query';
import { queryClient } from './query-client';
import { TodoPage } from './TodoPage';

createRoot(document.getElementById('root')!).render(
  <QueryClientProvider client={queryClient}>
    <TodoPage />
  </QueryClientProvider>,
);
EOF
cat > src/api/todos.ts <<'EOF'
export type Todo = { id: number; title: string };

export async function getTodos(): Promise<Todo[]> {
  const res = await fetch('/api/todos');
  return res.json();
}
EOF
cat > src/TodoPage.tsx <<'EOF'
import { useQuery } from '@tanstack/react-query';
import { getTodos } from './api/todos';

export function TodoPage() {
  const { data = [] } = useQuery({ queryKey: ['todos'], queryFn: getTodos });
  return <ul>{data.map((t) => <li key={t.id}>{t.title}</li>)}</ul>;
}
EOF
