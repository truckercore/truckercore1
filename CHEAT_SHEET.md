# TruckerCore Developer Cheat Sheet

🚀 One-Command Actions

```bash
# Development
npm run dev                    # Start dev server
npm run build                  # Build production bundle
npm run test:unit              # Run unit tests

# Deployment
npm run deploy                 # Deploy to production
npm run check:production       # Verify deployment

# Monitoring
npm run monitor                # Live dashboard
npm run monitor:logs           # Follow logs

# Quick Help
npm run quick-ref              # Show all commands
```

📁 Project Structure

```
truckercore1/
├── pages/              # Next.js pages (Router)
├── public/             # Static assets
├── styles/             # Global styles
├── scripts/            # Automation scripts
├── docs/               # Documentation
├── supabase/           # Supabase functions
└── package.json        # NPM scripts
```

🔧 Common Fixes

Build Fails

```bash
rm -rf .next node_modules
npm install
npm run build
```

Tests Fail

```bash
npm run test:unit -- --watch
# Fix failing tests
```

Deployment 404

```bash
npm run check:debug
# Follow suggestions
```

DNS Issues

```bash
npm run check:dns
# Follow DNS_CONFIGURATION.md
```

🆘 Emergency

Rollback Deployment

```bash
git revert HEAD
git push origin main
```

Check Production Health

```bash
curl https://truckercore.com
curl https://api.truckercore.com/health
```

View Recent Errors

```bash
npm run monitor:logs | grep error
```

🔗 Important URLs

Production:

- Homepage: https://truckercore.com
- App: https://app.truckercore.com
- API: https://api.truckercore.com/health

Dashboards:

- Vercel: https://vercel.com/your-org/truckercore1
- Supabase: https://app.supabase.com/project/your-project
- Sentry: https://sentry.io/organizations/your-org

📞 On-Call

- Primary: [Name] - [Phone]
- Secondary: [Name] - [Phone]
- Slack: #incidents

Keep this handy! 📌