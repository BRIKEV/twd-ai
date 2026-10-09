#!/usr/bin/env bash
# A minimal Angular CLI app (esbuild, no Vite config) with no TWD yet.
set -euo pipefail
mkdir -p src/app public
git init -q -b main . 2>/dev/null || true
cat > package.json <<'EOF'
{
  "name": "angular-todos",
  "private": true,
  "scripts": { "start": "ng serve", "build": "ng build" },
  "dependencies": {
    "@angular/common": "^20.3.0", "@angular/core": "^20.3.0",
    "@angular/platform-browser": "^20.3.0", "@angular/router": "^20.3.0", "rxjs": "~7.8.0"
  },
  "devDependencies": { "@angular/build": "^20.3.0", "@angular/cli": "^20.3.0", "typescript": "~5.9.0" }
}
EOF
cat > angular.json <<'EOF'
{
  "$schema": "./node_modules/@angular/cli/lib/config/schema.json",
  "version": 1,
  "projects": {
    "angular-todos": {
      "projectType": "application",
      "root": "",
      "sourceRoot": "src",
      "architect": {
        "build": {
          "builder": "@angular/build:application",
          "options": { "browser": "src/main.ts", "tsConfig": "tsconfig.app.json", "assets": [{ "glob": "**/*", "input": "public" }] },
          "configurations": {
            "production": { "outputHashing": "all" },
            "development": { "optimization": false, "sourceMap": true }
          },
          "defaultConfiguration": "production"
        },
        "serve": {
          "builder": "@angular/build:dev-server",
          "configurations": { "development": { "buildTarget": "angular-todos:build:development" } },
          "defaultConfiguration": "development"
        }
      }
    }
  }
}
EOF
echo '{ "compilerOptions": { "strict": true, "target": "ES2022", "module": "preserve" } }' > tsconfig.json
echo '{ "extends": "./tsconfig.json", "files": ["src/main.ts"], "include": ["src/**/*.ts"] }' > tsconfig.app.json
cat > src/index.html <<'EOF'
<!doctype html>
<html><body><app-root></app-root></body></html>
EOF
cat > src/main.ts <<'EOF'
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { App } from './app/app';

bootstrapApplication(App, appConfig).catch((err) => console.error(err));
EOF
cat > src/app/app.config.ts <<'EOF'
import { ApplicationConfig } from '@angular/core';

export const appConfig: ApplicationConfig = { providers: [] };
EOF
cat > src/app/app.ts <<'EOF'
import { Component } from '@angular/core';

@Component({ selector: 'app-root', template: '<h1>Todos</h1>' })
export class App {}
EOF
