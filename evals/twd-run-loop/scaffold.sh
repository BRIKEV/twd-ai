#!/usr/bin/env bash
# The todo app with a TWD suite where one test mocks the wrong URL, and a fake
# twd-cli in node_modules: no browser, but it honours --test, judges each test
# from its file (a getTodos mock on /api/todo fails), writes run.json and
# prints the console block in twd-cli's format, so the run-fix loop is real.
set -euo pipefail
mkdir -p src/twd-tests public node_modules/twd-cli node_modules/.bin
cat > package.json <<'EOF'
{
  "name": "todo-app",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "test:ci": "npx twd-cli run" },
  "dependencies": { "react": "^19.1.0", "react-dom": "^19.1.0" },
  "devDependencies": {
    "@vitejs/plugin-react": "^5.0.0", "typescript": "^5.9.0", "vite": "^7.1.0",
    "twd-js": "^1.10.1", "twd-cli": "^1.11.0"
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
import { describe, it, beforeEach } from 'twd-js/runner';
import { twd, userEvent, screenDom, expect } from 'twd-js';

describe('Todos', () => {
  beforeEach(() => {
    twd.clearRequestMockRules();
  });

  it('lists the todos', async () => {
    await twd.mockRequest('getTodos', {
      method: 'GET', url: '/api/todo', status: 200,
      response: [{ id: 1, title: 'Buy milk', done: false }],
    });
    await twd.visit('/');
    await twd.waitForRequest('getTodos');
    twd.should(await screenDom.findByText('Buy milk'), 'be.visible');
  });

  it('shows the empty state', async () => {
    await twd.mockRequest('getTodos', {
      method: 'GET', url: '/api/todos', status: 200, response: [],
    });
    await twd.visit('/');
    twd.should(await screenDom.findByText('No todos yet'), 'be.visible');
  });

  it('adds a todo', async () => {
    await twd.mockRequest('getTodos', {
      method: 'GET', url: '/api/todos', status: 200, response: [],
    });
    await twd.mockRequest('createTodo', {
      method: 'POST', url: '/api/todos', status: 201,
      response: { id: 2, title: 'Walk the dog', done: false },
    });
    await twd.visit('/');
    await userEvent.type(await screenDom.findByLabelText('New todo'), 'Walk the dog');
    await userEvent.click(screenDom.getByRole('button', { name: 'Add' }));
    const rule = await twd.waitForRequest('createTodo');
    expect(rule.request).to.deep.equal({ title: 'Walk the dog', done: false });
    twd.should(await screenDom.findByText('Walk the dog'), 'be.visible');
  });
});
EOF
echo '{ "name": "twd-cli", "version": "1.11.0", "bin": { "twd-cli": "bin.js" } }' > node_modules/twd-cli/package.json
cat > node_modules/twd-cli/bin.js <<'EOF'
#!/usr/bin/env node
// twd-cli for a sandbox without a browser. A test fails when it mocks a URL
// the app never fetches, as it would in the real runner.
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
if (args[0] !== 'run') {
  console.log('Usage: twd-cli run [--test <name>]... [--changed-since <ref>] [--report-dir <dir>]');
  process.exit(args.includes('--help') ? 0 : 1);
}
const filters = [];
let reportDir = '.twd/report';
for (let i = 1; i < args.length; i++) {
  if (args[i] === '--test') filters.push(args[++i]);
  else if (args[i] === '--report-dir') reportDir = args[++i];
  else if (args[i] === '--changed-since') i++;
}

const fetched = new Set([...fs.readFileSync('src/api.ts', 'utf8').matchAll(/fetch\(\s*['"`]([^'"`]+)/g)].map((m) => m[1]));
const dir = 'src/twd-tests';
const tests = [];
for (const file of fs.readdirSync(dir).filter((f) => /\.twd\.test\.tsx?$/.test(f))) {
  const src = fs.readFileSync(path.join(dir, file), 'utf8');
  const suite = (src.match(/describe\(\s*['"`]([^'"`]+)/) || [])[1] || file;
  const its = [...src.matchAll(/\bit(\.skip|\.only)?\(\s*['"`]([^'"`]+)['"`]/g)];
  its.forEach((m, n) => {
    const block = src.slice(m.index, n + 1 < its.length ? its[n + 1].index : src.length);
    tests.push({ path: `${suite} > ${m[2]}`, skip: m[1] === '.skip', wrongUrl: [...block.matchAll(/url:\s*['"`]([^'"`]+)/g)].some((u) => !fetched.has(u[1])) });
  });
}

const selected = filters.length
  ? tests.filter((t) => filters.some((f) => t.path.toLowerCase().includes(f.toLowerCase())))
  : tests;
const startedAt = new Date().toISOString();
const report = {
  schemaVersion: 3,
  run: { twdCliVersion: '1.11.0', url: 'http://localhost:5173', startedAt, endedAt: startedAt, durationMs: 0 },
  error: null,
  selection: { filters, selectedTests: selected.length },
  handlers: [],
  tests: [],
  outcome: 'passed',
  summary: { passed: 0, failed: 0, skipped: 0, notRun: 0, stoppedEarly: false,
    contracts: { passed: 0, errors: 0, warnings: 0, skipped: 0 } },
  recordings: [],
};
const write = () => {
  fs.mkdirSync(reportDir, { recursive: true });
  fs.writeFileSync(path.join(reportDir, 'run.json'), JSON.stringify(report, null, 2));
};

if (filters.length && selected.length === 0) {
  report.outcome = 'interrupted';
  report.error = { message: `No tests matched filter(s): ${filters.join(', ')}`, diagnostic: null };
  write();
  console.error(`✗ No tests matched filter(s): ${filters.join(', ')}`);
  process.exit(1);
}

const failed = [];
selected.forEach((t, i) => {
  const entry = { id: `t${i}`, path: t.path, index: i, attempts: 1 };
  if (t.skip) { entry.status = 'skip'; report.summary.skipped++; }
  else if (t.wrongUrl) {
    entry.status = 'fail';
    entry.attempts = 3;
    entry.error = 'Unable to find an element with the text: Buy milk (at http://localhost:5173/)';
    entry.diagnostics = { mockRules: { registered: 1, triggered: 0, untriggered: ['getTodos'] } };
    report.summary.failed++;
    failed.push(entry);
  } else { entry.status = 'pass'; report.summary.passed++; }
  report.tests.push(entry);
});
if (failed.length) report.outcome = 'failed';
write();

const s = report.summary;
console.log(`\n--- Run complete ---\n  Passed: ${s.passed} | Failed: ${s.failed} | Skipped: ${s.skipped}\n  Duration: 4.1s`);
if (failed.length) {
  console.log(`\n  Failed tests (${failed.length}):`);
  for (const f of failed) {
    console.log(`    × ${f.path}\n      mock rules  0/1 triggered — getTodos never requested\n      ${f.error}`);
  }
}
console.log(`\n  Report: ${reportDir}/index.html`);
process.exit(failed.length ? 1 : 0);
EOF
chmod +x node_modules/twd-cli/bin.js
ln -s ../twd-cli/bin.js node_modules/.bin/twd-cli
