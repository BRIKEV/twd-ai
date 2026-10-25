#!/usr/bin/env bash
# A Vite + React app with TWD already set up and Vitest for unit tests, and a
# pure date helper. The request is a Vitest unit test, which is not TWD's job.
set -euo pipefail
mkdir -p src/utils src/twd-tests public
cat > package.json <<'EOF'
{
  "name": "todo-app",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "test": "vitest", "test:ci": "npx twd-cli run" },
  "dependencies": { "react": "^19.1.0", "react-dom": "^19.1.0" },
  "devDependencies": {
    "@vitejs/plugin-react": "^5.0.0", "typescript": "^5.9.0", "vite": "^7.1.0",
    "vitest": "^3.2.0", "twd-js": "^1.10.1", "twd-cli": "^1.10.0"
  }
}
EOF
cat > vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { twd } from 'twd-js/vite-plugin';

export default defineConfig({
  plugins: [react(), twd({ testFilePattern: '/**/*.twd.test.{ts,tsx}', open: true, position: 'left' })],
  test: { include: ['src/**/*.test.ts'], exclude: ['src/**/*.twd.test.ts'] },
});
EOF
echo '{ "url": "http://localhost:5173", "coverage": false }' > twd.config.json
echo '// mock service worker placeholder' > public/mock-sw.js
cat > src/utils/date.ts <<'EOF'
/** Days from `from` to `to`, rounded down. Negative when `to` is earlier. */
export function daysBetween(from: Date, to: Date): number {
  const ms = to.getTime() - from.getTime();
  return Math.floor(ms / 86_400_000);
}

/** "today", "tomorrow", "yesterday", "in N days" or "N days ago". */
export function relativeDay(from: Date, to: Date): string {
  const days = daysBetween(from, to);
  if (days === 0) return 'today';
  if (days === 1) return 'tomorrow';
  if (days === -1) return 'yesterday';
  return days > 0 ? `in ${days} days` : `${-days} days ago`;
}
EOF
cat > src/twd-tests/todos.twd.test.ts <<'EOF'
import { describe, it, beforeEach } from 'twd-js/runner';
import { twd, screenDom } from 'twd-js';

describe('Todos', () => {
  beforeEach(() => {
    twd.clearRequestMockRules();
  });

  it('lists the todos', async () => {
    await twd.mockRequest('getTodos', {
      method: 'GET', url: '/api/todos', status: 200,
      response: [{ id: 1, title: 'Buy milk', done: false }],
    });
    await twd.visit('/');
    twd.should(await screenDom.findByText('Buy milk'), 'be.visible');
  });
});
EOF
