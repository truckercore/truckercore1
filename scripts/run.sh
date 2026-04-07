#!/bin/bash
# Quick run script for macOS/Linux
# Usage:
#   chmod +x scripts/run.sh
#   ./scripts/run.sh

flutter run \
  --dart-define=SUPABASE_URL=https://viqrwlzdtosxjzjvtxnr.supabase.co \
  --dart-define=SUPABASE_ANON=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpcXJ3bHpkdG9zeGp6anZ0eG5yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5MzUwNDgsImV4cCI6MjA3MDUxMTA0OH0.AQmHjD7UZT3vzkXYggUsi8XBEYWGQtXdFes6MDcUddk \
  --dart-define=USE_MOCK_DATA=false
