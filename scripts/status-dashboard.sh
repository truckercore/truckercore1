#!/bin/bash
# Live status dashboard (run in terminal)

while true; do
  clear
  echo "╔════════════════════════════════════════╗"
  echo "║     TruckerCore Status Dashboard       ║"
  echo "╚════════════════════════════════════════╝"
  echo ""
  echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  
  # Homepage status
  HOME_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://truckercore.com)
  HOME_TIME=$(curl -o /dev/null -s -w "%{time_total}s" https://truckercore.com)
  if [ "$HOME_STATUS" -eq 200 ]; then
    echo "✅ Homepage: $HOME_STATUS ($HOME_TIME)"
  else
    echo "❌ Homepage: $HOME_STATUS"
  fi
  
  # App status
  APP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://app.truckercore.com)
  if [ "$APP_STATUS" -eq 200 ]; then
    echo "✅ App: $APP_STATUS"
  else
    echo "❌ App: $APP_STATUS"
  fi
  
  # API status
  API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://api.truckercore.com/health)
  if [ "$API_STATUS" -eq 200 ]; then
    echo "✅ API: $API_STATUS"
  else
    echo "❌ API: $API_STATUS"
  fi
  
  echo ""
  echo "Press Ctrl+C to exit"
  
  sleep 10
done
