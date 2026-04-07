# Auto-fix common production readiness issues (Windows PowerShell)
Param()

function Write-Step($msg) { Write-Host "`n→ $msg" -ForegroundColor Yellow }
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                       ║" -ForegroundColor Cyan
Write-Host "║   AUTO-FIX PRODUCTION ISSUES                         ║" -ForegroundColor Cyan
Write-Host "║                                                       ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# 1) React fixes (root)
if (Test-Path "package.json") {
  Write-Host "`n1. Fixing React Application (root)" -ForegroundColor Cyan

  if (-not (Test-Path "package-lock.json")) {
    Write-Step "Generating package-lock.json"
    npm install --package-lock-only | Out-Null
  }

  if (-not (Test-Path "node_modules")) {
    Write-Step "Installing dependencies"
    npm install | Out-Null
  }

  if ((Test-Path "src/.env.example") -and -not (Test-Path ".env")) {
    Write-Step "Creating .env from src/.env.example"
    Copy-Item "src/.env.example" ".env"
    Write-Host "⚠ Remember to update .env with your actual values" -ForegroundColor Yellow
  }

  # Try a build
  Write-Step "Running TypeScript build to validate"
  npm run build | Out-Null
}

# 2) Flutter fixes
if (Test-Path "pubspec.yaml") {
  Write-Host "`n2. Fixing Flutter Application" -ForegroundColor Cyan

  if (-not (Test-Path ".env")) {
    Write-Step "Creating .env"
    @"
API_BASE_URL=http://localhost:3001/api
API_TIMEOUT=30000
USE_MOCK_DATA=true
ENABLE_ANALYTICS=false
ENABLE_GEOLOCATION=true
DEBUG_LOGGING=true
"@ | Out-File -FilePath .env -Encoding UTF8
  }

  Write-Step "Getting Flutter dependencies"
  flutter pub get | Out-Null

  if ((Select-String -Path "pubspec.yaml" -Pattern "build_runner" -Quiet)) {
    Write-Step "Running code generation"
    flutter pub run build_runner build --delete-conflicting-outputs | Out-Null
  }

  Write-Step "Formatting Dart code"
  dart format . | Out-Null
}

# 3) Ensure .gitignore
Write-Step "Ensuring .gitignore has essential entries"
@"
# Dependencies
node_modules/
/.pnp
.pnp.js

# Testing
/coverage

# Builds
/build
/dist

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*
logs/
*.log

# IDEs
.vscode/
.idea/
*.iml

# OS
.DS_Store
Thumbs.db

# Env files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
*.env.*.local

# Flutter/Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.pub-cache/
.pub/
/android/app/debug
/android/app/profile
/android/app/release
/build/
*.g.dart
*.freezed.dart

# iOS/Android signing
/android/key.properties
*.jks
*.keystore

# Other
.eslintcache
"@ | Out-File -FilePath .gitignore -Encoding UTF8

# 4) Pre-commit template
if (-not (Test-Path "scripts")) { New-Item -ItemType Directory -Path scripts | Out-Null }
@"
#!/usr/bin/env bash
set -e
ERRORS=0
if [ -f package.json ]; then
  if grep -R "console\\.log" src --exclude-dir=node_modules --include='*.ts*' 2>/dev/null; then
    echo "❌ console.log statements found in React code"; ERRORS=$((ERRORS+1)); fi
  npm run -s build >/dev/null 2>&1 || { echo "❌ React build failed"; ERRORS=$((ERRORS+1)); }
fi
if [ -f pubspec.yaml ]; then
  flutter analyze >/dev/null 2>&1 || { echo "❌ Flutter analyze failed"; ERRORS=$((ERRORS+1)); }
fi
[ "$ERRORS" -ne 0 ] && { echo "❌ Pre-commit checks failed"; exit 1; }
echo "✓ Pre-commit checks passed"
"@ | Out-File -FilePath scripts/pre-commit.sample -Encoding UTF8

Write-Host "`n✓ Auto-fix complete" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Review changes made by this script"
Write-Host "2. Update .env with actual values"
Write-Host "3. Optionally copy scripts/pre-commit.sample to .git/hooks/pre-commit"
Write-Host "4. Run './verify-production-ready.sh' again"
