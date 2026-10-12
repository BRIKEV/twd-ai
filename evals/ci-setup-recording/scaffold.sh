#!/usr/bin/env bash
# A Vite + React app with TWD tests, an env var it throws without, and a
# json-server mock API it fetches from on load. No CI yet.
set -euo pipefail
mkdir -p src/twd-tests public
cat > package.json <<'EOF'
{
  "name": "todo-app",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "serve": "json-server --port 3001 db.json",
    "serve:dev": "run-p serve dev",
    "test:ci": "npx twd-cli run"
  },
  "dependencies": { "react": "^19.1.0", "react-dom": "^19.1.0" },
  "devDependencies": {
    "@vitejs/plugin-react": "^5.0.0", "json-server": "^1.0.0-beta.3", "npm-run-all": "^4.1.5",
    "typescript": "^5.9.0", "vite": "^7.1.0", "twd-js": "^1.10.1", "twd-cli": "^1.10.0"
  }
}
EOF
echo '{ "todos": [] }' > db.json
echo 'VITE_API_URL=http://localhost:3001' > .env.example
cat > vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { twd } from 'twd-js/vite-plugin';

export default defineConfig({
  plugins: [react(), twd({ testFilePattern: '/**/*.twd.test.{ts,tsx}', open: true, position: 'left' })],
});
EOF
echo '{ "url": "http://localhost:5173", "coverage": false }' > twd.config.json
printf 'node_modules/\n.twd/\n' > .gitignore
echo '// mock service worker placeholder' > public/mock-sw.js
cat > src/api.ts <<'EOF'
const base = import.meta.env.VITE_API_URL;
if (!base) throw new Error('VITE_API_URL is not set');

export async function getTodos() {
  const res = await fetch(`${base}/todos`);
  return res.json();
}
EOF
cat > src/twd-tests/todos.twd.test.ts <<'EOF'
import { twd, screenDom } from "twd-js";
import { describe, it, beforeEach } from "twd-js/runner";

describe("Todo page", () => {
  beforeEach(() => {
    twd.clearRequestMockRules();
  });

  it("should load the list", async () => {
    await twd.mockRequest("getTodos", {
      method: "GET",
      url: "http://localhost:3001/todos",
      response: [{ id: 1, title: "Buy milk" }],
    });
    await twd.visit("/");
    await twd.waitForRequest("getTodos");
    twd.should(await screenDom.findByText("Buy milk"), "be.visible");
  });
});
EOF
