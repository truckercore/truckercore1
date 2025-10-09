#!/usr/bin/env bash

# TruckerCore Complete Setup Script (Unix)
set -e

echo "🚀 TruckerCore Setup Script"
echo "============================"

# Check Node
if ! command -v node >/dev/null 2>&1; then
  echo "❌ Node.js is not installed" >&2
  exit 1
fi
node --version

if ! command -v npm >/dev/null 2>&1; then
  echo "❌ npm is not installed" >&2
  exit 1
fi
npm --version

echo "📦 Installing dependencies..."
npm install

echo "📝 Ensuring .env exists..."
if [ ! -f .env ]; then
  if [ -f env.example ]; then
    cp env.example .env
    echo "Created .env from env.example (edit with your values)"
  fi
fi

# Create directories
mkdir -p resources dist-electron release logs

# Run migrations (no-op if sqlite not available)
echo "🗄️  Running database migrations..."
npm run migrate || true

# Build
echo "🏗️  Building Next.js..."
npm run build

echo "⚡ Building Electron..."
npm run build:electron

# Quick tests (unit)
echo "🧪 Running unit tests..."
npm run test:unit || true

echo "✅ Setup completed. Next: npm run electron:dev" 
