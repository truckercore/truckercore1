#!/bin/bash
# Setup monitoring & alerts guidance for TruckerCore production
set -euo pipefail

echo "📊 Setting up production monitoring..."
echo ""

# 1. Vercel integrations
echo "1️⃣ Vercel Integration Monitoring"
echo "   Visit: https://vercel.com/integrations/monitoring"
echo "   Recommended: Better Uptime, Checkly, or Datadog"
echo ""

# 2. Sentry alerting
echo "2️⃣ Sentry Alert Rules"
echo "   Visit: https://sentry.io/settings/your-org/projects/truckercore/alerts/"
echo "   Suggested alerts:"
echo "   - Error rate > 1% in 5 minutes"
echo "   - New issue type detected"
echo "   - Performance degradation (p95 > 2s)"
echo ""

# 3. Uptime monitoring
echo "3️⃣ Uptime Monitoring"
echo "   Recommended services:"
echo "   - UptimeRobot: https://uptimerobot.com"
echo "   - Better Uptime: https://betteruptime.com"
echo "   - Pingdom: https://pingdom.com"
echo ""
echo "   Monitor these URLs:"
echo "   - https://truckercore.com"
echo "   - https://app.truckercore.com"
echo "   - https://api.truckercore.com/health"
echo ""

# 4. Create simple uptime check helper
cat > uptime-check.sh << 'UPTIME_EOF'
#!/bin/bash
# Simple uptime check (run every 5 minutes via cron)

URLS=(
  "https://truckercore.com"
  "https://app.truckercore.com"
  "https://api.truckercore.com/health"
)

WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"  # Set this in environment

for url in "${URLS[@]}"; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [ "$status" -ne 200 ]; then
    echo "[$(date)] ❌ $url returned $status"
    # Send alert to Slack (if configured)
    if [ -n "$WEBHOOK_URL" ]; then
      curl -X POST "$WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"🚨 $url is down! Status: $status\"}"
    fi
  else
    echo "[$(date)] ✅ $url is up ($status)"
  fi
done
UPTIME_EOF

chmod +x uptime-check.sh

echo "4️⃣ Created uptime-check.sh"
echo "   Add to crontab: */5 * * * * /path/to/uptime-check.sh"
echo ""

echo "✅ Monitoring setup guide complete!"
echo ""
echo "Next steps:"
echo "1. Sign up for monitoring service (UptimeRobot recommended)"
echo "2. Configure Sentry alert rules"
echo "3. Set up Slack/email notifications"
echo "4. Test alerts by temporarily breaking a page"