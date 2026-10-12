#!/usr/bin/env bash
# A minimal Vite + React todo app with TWD wired, no node_modules. The agent
# only reads and writes files, so nothing needs installing.
set -euo pipefail
mkdir -p src/twd-tests public
cat > package.json <<'EOF'
{
  "name": "todo-app",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "test:ci": "npx twd-cli run" },
  "dependencies": { "react": "^19.1.0", "react-dom": "^19.1.0" },
  "devDependencies": {
    "@vitejs/plugin-react": "^5.0.0", "typescript": "^5.9.0", "vite": "^7.1.0",
    "twd-js": "^1.10.1", "twd-cli": "^1.10.0"
  }
}
EOF
cat > vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { twd } from 'twd-js/vite-plugin';

export default defineConfig({
  plugins: [react(), twd({ testFilePattern: '/**/*.twd.test.{ts,tsx}', open: true, position: 'left' })],
});
EOF
echo '{ "url": "http://localhost:5173", "coverage": false }' > twd.config.json
echo '// mock service worker placeholder' > public/mock-sw.js
cat > index.html <<'EOF'
<!doctype html>
<html><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
EOF
cat > src/main.tsx <<'EOF'
import { createRoot } from 'react-dom/client';
import { TodoPage } from './TodoPage';

createRoot(document.getElementById('root')!).render(<TodoPage />);
EOF
cat > src/api.ts <<'EOF'
export type Todo = { id: number; title: string; done: boolean };

export async function getTodos(): Promise<Todo[]> {
  const res = await fetch('/api/todos');
  if (!res.ok) throw new Error('Failed to load todos');
  return res.json();
}

export async function createTodo(title: string): Promise<Todo> {
  const res = await fetch('/api/todos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title, done: false }),
  });
  if (!res.ok) throw new Error('Failed to create todo');
  return res.json();
}
EOF
cat > src/TodoPage.tsx <<'EOF'
import { useEffect, useState } from 'react';
import { getTodos, createTodo, type Todo } from './api';

export function TodoPage() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [title, setTitle] = useState('');

  useEffect(() => {
    getTodos().then(setTodos).catch((e) => setError(e.message));
  }, []);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    const todo = await createTodo(title);
    setTodos((t) => [...t, todo]);
    setTitle('');
  }

  return (
    <main>
      <h1>Todos</h1>
      {error && <p role="alert">{error}</p>}
      {!error && todos.length === 0 && <p>No todos yet</p>}
      <ul>{todos.map((t) => <li key={t.id}>{t.title}</li>)}</ul>
      <form onSubmit={onSubmit}>
        <label htmlFor="title">New todo</label>
        <input id="title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <button type="submit">Add</button>
      </form>
    </main>
  );
}
EOF
