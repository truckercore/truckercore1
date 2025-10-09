#!/bin/bash
# TruckerCore Deployment Quick Reference

cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║         TruckerCore Deployment Quick Reference            ║
╚═══════════════════════════════════════════════════════════╝

📦 DEPLOYMENT COMMANDS
────────────────────────────────────────────────────────────
  npm run deploy              Full deployment with tests
  npm run deploy:fast         Deploy without tests
  npm run deploy:force        Deploy without prompts (CI/CD)

🔍 STATUS & VERIFICATION
────────────────────────────────────────────────────────────
  npm run check:status        Check deployment readiness
  npm run check:production    Verify production deployment
  npm run check:debug         Debug 404 issues

🧪 TESTING
────────────────────────────────────────────────────────────
  npm run test:predeploy      Run all pre-deploy tests
  npm run test:routes         Test local routes
  npm run test:unit           Run unit tests
  npm run validate:seo        Validate SEO meta tags

📊 MONITORING
────────────────────────────────────────────────────────────
  npm run monitor             Live status dashboard
  npm run monitor:logs        Follow Vercel logs
  vercel inspect <url>        Inspect specific deployment

🛠️ MAINTENANCE
────────────────────────────────────────────────────────────
  npm run assets:generate     Generate icon placeholders
  npm run assets:check        Check asset file sizes
  vercel env ls               List environment variables
  vercel domains ls           List configured domains

🚨 EMERGENCY
────────────────────────────────────────────────────────────
  git revert HEAD && git push Rollback via Git
  vercel rollback             Rollback via Vercel CLI
  vercel inspect --logs       Check recent error logs

📝 QUICK CHECKS
────────────────────────────────────────────────────────────
  curl -I https://truckercore.com
  curl https://api.truckercore.com/health | jq
  lighthouse https://truckercore.com --view

🔗 DASHBOARD LINKS
────────────────────────────────────────────────────────────
  Vercel:    https://vercel.com/your-org/truckercore1
  Supabase:  https://app.supabase.com/project/your-project
  Sentry:    https://sentry.io/organizations/your-org

EOF
