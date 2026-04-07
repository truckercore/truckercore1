#!/bin/bash
# Monitor site health during launch

DOMAIN=${DOMAIN:-"https://truckercore.com"}
INTERVAL=${INTERVAL:-60}  # seconds

echo "📊 Monitoring $DOMAIN"
echo "Press Ctrl+C to stop"
echo ""

while true; do
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  status=$(curl -s -o /dev/null -w "%{http_code}" "$DOMAIN")
  response_time=$(curl -o /dev/null -s -w "%{time_total}" "$DOMAIN")
  response_time_ms=$(echo "$response_time * 1000" | bc)
  
  if [ "$status" -eq 200 ]; then
    echo "[$timestamp] ✅ Status: $status | Response: ${response_time_ms}ms"
  else
    echo "[$timestamp] ❌ Status: $status | Response: ${response_time_ms}ms"
    # TODO: Integrate alerting here (Slack/Webhook)
  fi
  
  sleep $INTERVAL
done
