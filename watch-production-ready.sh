#!/usr/bin/env bash
# Continuous verification - runs every 5 minutes
set -e

echo "Starting continuous production readiness monitoring..."
echo "Press Ctrl+C to stop"

while true; do
  clear || true
  date
  echo ""
  if [ -x ./verify-production-ready.sh ]; then
    ./verify-production-ready.sh || true
  else
    bash verify-production-ready.sh || true
  fi
  echo ""
  echo "Next check in 5 minutes..."
  sleep 300
done
