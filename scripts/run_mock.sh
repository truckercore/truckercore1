#!/bin/bash
# Quick run script for macOS/Linux (Mock Data Mode)
# Usage:
#   chmod +x scripts/run_mock.sh
#   ./scripts/run_mock.sh

flutter run \
  --dart-define=USE_MOCK_DATA=true
