#!/usr/bin/env bash
# Vite + React app with Testing Library, and a dialog component that is the
# subject of a component test. No node_modules: the agent only writes files.
set -euo pipefail
mkdir -p src/components src/twd-tests public
cat > package.json <<'EOF'
{
  "name": "todo-app",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "test:ci": "npx twd-cli run" },
  "dependencies": { "react": "^19.1.0", "react-dom": "^19.1.0" },
  "devDependencies": {
    "@testing-library/react": "^16.3.0", "@vitejs/plugin-react": "^5.0.0",
    "typescript": "^5.9.0", "vite": "^7.1.0", "twd-js": "^1.10.1", "twd-cli": "^1.10.0"
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
import { AddTodoDialog } from './components/AddTodoDialog';

createRoot(document.getElementById('root')!).render(<AddTodoDialog />);
EOF
cat > src/components/AddTodoDialog.tsx <<'EOF'
import { useState } from 'react';

export function AddTodoDialog() {
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  async function save() {
    if (!title.trim()) {
      setError('Title is required');
      return;
    }
    const res = await fetch('/api/todos', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title }),
    });
    if (!res.ok) {
      setError('Could not save the todo');
      return;
    }
    setSaved(true);
    setOpen(false);
  }

  return (
    <div>
      <button onClick={() => { setOpen(true); setError(null); }}>Add todo</button>
      {saved && <p>Todo saved</p>}
      {open && (
        <div role="dialog" aria-label="Add todo">
          <label htmlFor="todo-title">Title</label>
          <input id="todo-title" value={title} onChange={(e) => setTitle(e.target.value)} />
          {error && <p role="alert">{error}</p>}
          <button onClick={save}>Save</button>
          <button onClick={() => setOpen(false)}>Cancel</button>
        </div>
      )}
    </div>
  );
}
EOF
