# TruckerCore Complete Setup Script (Windows)
Param()

Write-Host "🚀 TruckerCore Setup Script" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

# Check Node
try {
  $nodeVersion = node --version
  Write-Host "✓ Node.js: $nodeVersion" -ForegroundColor Green
} catch {
  Write-Host "❌ Node.js is not installed" -ForegroundColor Red
  exit 1
}

try {
  $npmVersion = npm --version
  Write-Host "✓ npm: $npmVersion" -ForegroundColor Green
} catch {
  Write-Host "❌ npm is not installed" -ForegroundColor Red
  exit 1
}

Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
npm install
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to install dependencies" -ForegroundColor Red; exit 1 }

# Ensure .env
if (-not (Test-Path ".env")) {
  if (Test-Path "env.example") {
    Copy-Item env.example .env
    Write-Host "Created .env from env.example (edit with your values)" -ForegroundColor Green
  }
}

# Create directories
New-Item -ItemType Directory -Force -Path resources | Out-Null
New-Item -ItemType Directory -Force -Path dist-electron | Out-Null
New-Item -ItemType Directory -Force -Path release | Out-Null
New-Item -ItemType Directory -Force -Path logs | Out-Null

# Run migrations (no-op if sqlite not available)
Write-Host "🗄️  Running database migrations..." -ForegroundColor Yellow
npm run migrate

# Build
Write-Host "🏗️  Building Next.js..." -ForegroundColor Yellow
npm run build
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Next.js build failed" -ForegroundColor Red; exit 1 }

Write-Host "⚡ Building Electron..." -ForegroundColor Yellow
npm run build:electron
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Electron build failed" -ForegroundColor Red; exit 1 }

Write-Host "🧪 Running unit tests..." -ForegroundColor Yellow
npm run test:unit

Write-Host "✅ Setup completed successfully! Next: npm run electron:dev" -ForegroundColor Green
