#!/usr/bin/env bash
# The twd-flow-test todo app, plus a test file with the four mistakes twd-lint
# reports planted in it. Nothing is installed.
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
cat > src/twd-tests/todos.twd.test.ts <<'EOF'
import { describe, it, beforeEach, expect } from 'vitest';
import { twd, userEvent, screenDom } from 'twd-js';

describe('Todos', () => {
  beforeEach(() => {
    twd.clearRequestMockRules();
  });

  it('lists the todos', async () => {
    twd.mockRequest('getTodos', {
      method: 'GET',
      url: '/api/todos',
      response: [{ id: 1, title: 'Buy milk', done: false }],
      status: 200,
    });
    await twd.visit('/');
    await twd.waitForRequest('getTodos');
    twd.should(await screenDom.findByText('Buy milk'), 'be.visible');
  });

  it.only('adds a todo', async () => {
    await twd.mockRequest('getTodos', { method: 'GET', url: '/api/todos', response: [], status: 200 });
    await twd.mockRequest('createTodo', {
      method: 'POST',
      url: '/api/todos',
      response: { id: 2, title: 'Walk the dog', done: false },
      status: 201,
    });
    await twd.visit('/');
    userEvent.type(await screenDom.findByLabelText('New todo'), 'Walk the dog');
    await userEvent.click(screenDom.getByRole('button', { name: 'Add' }));
    const rule = await twd.waitForRequest('createTodo');
    expect(rule.request.body.title).to.equal('Walk the dog');
  });
});
EOF
