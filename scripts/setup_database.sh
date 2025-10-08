#!/bin/bash
set -e

echo "🗄️  Setting up Supabase Database..."

: ${SUPABASE_PROJECT_ID:?"SUPABASE_PROJECT_ID not set"}
: ${SUPABASE_ACCESS_TOKEN:?"SUPABASE_ACCESS_TOKEN not set"}

echo "Installing Supabase CLI (if not installed)..."
if ! command -v supabase &> /dev/null; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install supabase/tap/supabase
  else
    curl -sL https://github.com/supabase/cli/releases/latest/download/supabase_$(uname -s | tr '[:upper:]' '[:lower:]')_$(uname -m).tar.gz | tar -xz -C /usr/local/bin supabase || true
  fi
fi

echo "Logging in to Supabase..."
supabase login --token "$SUPABASE_ACCESS_TOKEN"

echo "Linking to project..."
supabase link --project-ref "$SUPABASE_PROJECT_ID"

echo "Applying database schema..."
# Ensure schema file exists
if [ -f "supabase/schema.sql" ]; then
  supabase db push
else
  echo "supabase/schema.sql not found; skipping db push"
fi

echo "Creating demo data (optional manual step)..."
echo "Use Supabase SQL editor or psql with DATABASE_URL to insert demo rows."
cat <<'EOF'
-- Example: Create demo driver status once users exist
-- INSERT INTO driver_status (driver_id, status, drive_time_left, shift_time_left, cycle_time_left)
-- SELECT id, 'on_duty', 8.75, 10.5, 45.0
-- FROM auth.users WHERE email = 'driver@demo.com'
-- ON CONFLICT (driver_id) DO NOTHING;
EOF

echo "✅ Database setup complete!"
echo ""
echo "Next steps:"
echo "1. Create user accounts in Supabase Dashboard"
echo "2. Set user metadata: {\"primary_role\": \"driver\", \"roles\": [\"driver\"]}"
echo "3. Test login with the credentials"