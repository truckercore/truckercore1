#!/bin/bash

echo "🚀 Starting Fleet Manager Dashboard Testing"
echo "==========================================="
echo ""

# Move into web app directory
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
WEB_DIR="$REPO_ROOT/apps/web"
cd "$WEB_DIR" || exit 1

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ npm version: $(npm --version)"
echo ""

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
else
    echo "✅ Dependencies already installed"
fi
echo ""

# Check environment variables
if [ ! -f ".env.local" ]; then
    echo "⚠️  .env.local not found. Creating from template..."
    cat > .env.local << EOF
DATABASE_URL=postgresql://localhost:5432/fleet_db
NEXT_PUBLIC_WS_URL=ws://localhost:3000
NEXT_PUBLIC_MAP_STYLE_URL=https://basemaps.cartocdn.com/gl/positron-gl-style/style.json
NEXT_PUBLIC_APP_URL=http://localhost:3000
NODE_ENV=development
EOF
    echo "✅ Created .env.local"
else
    echo "✅ .env.local exists"
fi
echo ""

# Run type check
echo "🔍 Running TypeScript type check..."
npm run type-check
if [ $? -eq 0 ]; then
    echo "✅ No type errors found"
else
    echo "❌ TypeScript errors found. Please fix before testing."
    exit 1
fi
echo ""

# Start development server
echo "🚀 Starting development server..."
echo ""
echo "Once server starts, open your browser to:"
echo "  📍 Fleet Dashboard: http://localhost:3000/fleet/dashboard"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

npm run dev
