#!/usr/bin/env bash
# A Vite + React page around a third-party camera scanner, already wrapped in
# <MockedComponent name="qrScanner">. No node_modules: the agent only writes.
set -euo pipefail
mkdir -p src/twd-tests public
cat > package.json <<'EOF'
{
  "name": "qr-app",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "test:ci": "npx twd-cli run" },
  "dependencies": {
    "@yudiel/react-qr-scanner": "^2.5.1", "react": "^19.1.0", "react-dom": "^19.1.0"
  },
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
import { QrScannerPage } from './QrScannerPage';

createRoot(document.getElementById('root')!).render(<QrScannerPage />);
EOF
cat > src/QrScannerPage.tsx <<'EOF'
import { useState } from 'react';
import { Scanner } from '@yudiel/react-qr-scanner';
import { MockedComponent } from 'twd-js/ui';

export function QrScannerPage() {
  const [codes, setCodes] = useState<string[]>([]);

  const handleScan = (detected: Array<{ rawValue: string }>) => {
    const scanned = detected.map((code) => code.rawValue);
    setCodes((prev) => Array.from(new Set([...prev, ...scanned])));
  };

  return (
    <main>
      <h1>QR Code Scanner</h1>
      <MockedComponent name="qrScanner">
        <Scanner onScan={handleScan} onError={(error) => console.error(error)} />
      </MockedComponent>
      <p>{codes.length === 0 ? 'No codes detected yet' : `${codes.length} code(s) detected`}</p>
      {codes.length > 0 && (
        <>
          <button onClick={() => setCodes([])}>Clear all</button>
          <ul>{codes.map((code) => <li key={code}>{code}</li>)}</ul>
        </>
      )}
    </main>
  );
}
EOF
