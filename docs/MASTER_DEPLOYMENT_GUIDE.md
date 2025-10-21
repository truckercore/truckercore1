# TruckerCore - Master Deployment Guide

## Overview

Complete deployment guide for all TruckerCore components across all platforms.

## Quick Navigation

| Component | Documentation | Quick Deploy |
|-----------|---------------|--------------|
| **Safety Summary Suite** | [Deployment Summary](./deployment/DEPLOYMENT_SUMMARY.md) | `npm run deploy:safety-suite[:win]` |
| **Homepage** | [Homepage Summary](./homepage/HOMEPAGE_SUMMARY.md) | `git push origin main` (auto-deploy) |
| **API/Backend** | [API Docs](./api/README.md) | `npm run deploy:functions` |
| **Mobile App** | [Mobile Docs](./mobile/README.md) | Platform-specific |

## Platform Support Matrix

| Feature | Windows | Unix/Linux | macOS | CI/CD |
|---------|---------|------------|-------|-------|
| Safety Suite Deploy | ✅ PowerShell | ✅ Bash/Node | ✅ Bash/Node | ✅ GitHub Actions |
| Homepage Deploy | ✅ Vercel | ✅ Vercel | ✅ Vercel | ✅ Auto |
| Verification | ✅ PS/Node | ✅ Node | ✅ Node | ✅ Node |
| Environment Setup | ✅ Interactive | ✅ Manual | ✅ Manual | ✅ Secrets |

## One-Command Deploy

### Safety Summary Suite

**Windows:**

```powershell
# First time
.\scripts\Setup-Environment.ps1 -Save
npm run deploy:safety-suite:win
npm run verify:safety-suite:full

# Subsequent deploys
npm run deploy:safety-suite:win
```

**Unix/Linux/macOS:**

```bash
# First time
export SUPABASE_URL="https://xxx.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
npm run deploy:safety-suite
npm run verify:safety-suite:full

# Subsequent deploys
npm run deploy:safety-suite
```

### Homepage

**All Platforms:**

```bash
# Auto-deploys on push to main
git add app/
git commit -m "feat: update homepage"
git push origin main

# Verify
npm run verify:homepage:prod
```

## Environment Variables Reference

### Required for Safety Suite

| Variable | Purpose | Example | Where Used |
|----------|---------|---------|------------|
| `SUPABASE_URL` | Project URL | `https://xxx.supabase.co` | All scripts |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin access | `eyJhbGc...` | Server-side only |

### Optional

| Variable | Purpose | Default | Where Used |
|----------|---------|---------|------------|
| `SUPABASE_ANON_KEY` | Client access | From env | Client/verification |
| `NEXT_PUBLIC_SUPABASE_URL` | Public URL | Same as SUPABASE_URL | Next.js |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Public anon | Same as SUPABASE_ANON_KEY | Next.js |

### Setting Variables

**Windows (PowerShell):**

```powershell
# Session (temporary)
$env:SUPABASE_URL = "https://xxx.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..."

# User scope (permanent)
[Environment]::SetEnvironmentVariable("SUPABASE_URL", "https://xxx.supabase.co", "User")

# Or use interactive setup
.\scripts\Setup-Environment.ps1 -Save
```

**Unix/Linux/macOS:**

```bash
# Session (temporary)
export SUPABASE_URL="https://xxx.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."

# Permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export SUPABASE_URL="https://xxx.supabase.co"' >> ~/.bashrc
echo 'export SUPABASE_SERVICE_ROLE_KEY="eyJ..."' >> ~/.bashrc
source ~/.bashrc

# Or use .env file (for Node.js scripts)
cat > .env << EOF
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
EOF
```

## Deployment Workflows

### Development → Staging → Production

```bash
# 1. Develop locally
git checkout -b feature/new-feature
npm run dev
# Make changes, test locally

# 2. Deploy to staging
git push origin feature/new-feature
# Vercel preview deploy auto-triggers
# Review at: https://truckercore-git-feature-new-feature.vercel.app

# 3. Run verification on staging
BASE_URL=https://truckercore-git-feature-new-feature.vercel.app \
  npm run verify:homepage

# 4. Merge to main (production)
git checkout main
git merge feature/new-feature
git push origin main
# Auto-deploys to https://truckercore.com

# 5. Verify production
npm run verify:homepage:prod
npm run verify:safety-suite:full
```

### Hotfix Workflow

```bash
# 1. Create hotfix branch from main
git checkout main
git checkout -b hotfix/critical-fix

# 2. Make fix
# ... edit files ...

# 3. Test locally
npm run build
npm run start

# 4. Deploy directly to production
git checkout main
git merge hotfix/critical-fix
git push origin main

# 5. Verify immediately
npm run verify:homepage:prod
npm run verify:safety-suite:full

# 6. Monitor for 15 minutes
watch -n 30 'npm run verify:homepage:prod'
```

## Rollback Procedures

### Homepage Rollback

```bash
# Option A: Revert commit
git revert HEAD
git push origin main
# Vercel auto-deploys previous version

# Option B: Redeploy previous commit
git checkout main
git reset --hard HEAD~1
git push --force origin main
# WARNING: Force push - use with caution

# Option C: Vercel dashboard
# 1. Go to vercel.com/dashboard
# 2. Select project
# 3. Click "Deployments"
# 4. Find previous deployment
# 5. Click "..." → "Promote to Production"
```

### Safety Suite Rollback

```bash
# 1. Disable CRON immediately
supabase functions unschedule refresh-safety-summary

# 2. Revert Edge Function
git checkout HEAD~1 -- supabase/functions/refresh-safety-summary/
supabase functions deploy refresh-safety-summary

# 3. Revert migration (CAUTION: May lose data)
supabase db reset
# Restore from backup if available

# 4. Hide UI components temporarily
# Edit dashboard files to comment out imports:
# // import { SafetySummaryCard } from '...';

git add apps/web/pages/
git commit -m "fix: temporarily disable Safety Suite UI"
git push origin main

# 5. Verify rollback
npm run verify:safety-suite:full
```

## Monitoring & Alerts

### Key Metrics to Monitor

**Homepage:**
- Uptime: >99.9%
- Response time: <1s (p95)
- Error rate: <0.1%
- Core Web Vitals: LCP <2.5s, FID <100ms, CLS <0.1

**Safety Suite:**
- Edge Function success rate: >99%
- RPC execution time: <10s (p95)
- CRON execution: Daily at 06:00 UTC
- Data freshness: <24h

### Monitoring Tools

**Vercel Analytics** (Homepage):

```bash
# Enable in Vercel dashboard
# Settings → Analytics → Enable
# View at: vercel.com/dashboard/analytics
```

**Supabase Logs** (Safety Suite):

```bash
# Real-time logs
supabase functions logs refresh-safety-summary --follow

# Recent errors
supabase functions logs refresh-safety-summary --tail 100 | grep ERROR

# Export logs
supabase functions logs refresh-safety-summary --tail 1000 > logs.txt
```

**Custom Monitoring Script:**

```bash
# Add to crontab for hourly checks
0 * * * * cd /path/to/repo && npm run verify:homepage:prod >> /var/log/homepage-health.log 2>&1
0 * * * * cd /path/to/repo && npm run verify:safety-suite >> /var/log/safety-health.log 2>&1
```

## Troubleshooting

### Common Issues Across All Platforms

| Issue | Platform | Solution |
|-------|----------|----------|
| "Command not found: supabase" | All | `npm install -g supabase` |
| "Missing environment variables" | All | Run setup script or export manually |
| "Permission denied" | Windows | Run PowerShell as Administrator |
| "Execution policy" | Windows | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| "Project not linked" | All | `supabase link --project-ref YOUR_REF` |
| "Build fails" | All | Delete `.next` and `node_modules`, reinstall |
| "Port already in use" | All | `kill $(lsof -ti:3000)` (Unix) or Task Manager (Windows) |

### Debug Mode

**Safety Suite:**

```bash
# Unix
DEBUG=1 npm run deploy:safety-suite

# Windows
$env:DEBUG=1; npm run deploy:safety-suite:win

# Dry run (no changes)
npm run deploy:safety-suite:dry
npm run deploy:safety-suite:win-dry
```

**Homepage:**

```bash
# Local development with verbose logging
npm run dev -- --verbose

# Build with debug info
npm run build -- --debug
```

## Security Checklist

Before deploying to production:

- [ ] All `SUPABASE_SERVICE_ROLE_KEY` uses are server-side only
- [ ] No secrets in Git history (`git log --all --grep="eyJ"`)
- [ ] `.env` file in `.gitignore`
- [ ] RLS policies enabled on all tables
- [ ] HTTPS enforced (Vercel does this automatically)
- [ ] CORS configured correctly
- [ ] Rate limiting enabled on API routes
- [ ] Secrets rotated in last 90 days
- [ ] Security headers set (CSP, HSTS, X-Frame-Options)

## Performance Optimization

### Homepage

```bash
# Analyze bundle size
npm run build
npx @next/bundle-analyzer

# Lighthouse audit
npx lighthouse https://truckercore.com --view

# Image optimization (if adding images)
# Use next/image component
import Image from 'next/image';
```

### Safety Suite

```sql
-- Add indexes if queries are slow
CREATE INDEX CONCURRENTLY idx_alert_events_org_created 
ON public.alert_events(org_id, created_at DESC);

-- Vacuum and analyze
VACUUM ANALYZE public.safety_daily_summary;
VACUUM ANALYZE public.risk_corridor_cells;

-- Check slow queries
SELECT * FROM pg_stat_statements 
ORDER BY total_exec_time DESC 
LIMIT 10;
```

## Cost Monitoring

### Supabase Free Tier Limits

| Resource | Limit | Current Usage | Check |
|----------|-------|---------------|-------|
| Database Storage | 500 MB | ? | Supabase dashboard |
| Bandwidth | 5 GB/mo | ? | Supabase dashboard |
| Edge Function Invocations | 500k/mo | ~3k/mo | Supabase dashboard |
| Database Rows | 500k | ? | `SELECT COUNT(*) FROM ...` |

### Vercel Free Tier Limits

| Resource | Limit | Current Usage | Check |
|----------|-------|---------------|-------|
| Bandwidth | 100 GB/mo | ? | Vercel dashboard |
| Build Minutes | 6k/mo | ? | Vercel dashboard |
| Serverless Function Execution | 100 GB-hrs/mo | ? | Vercel dashboard |

**Alerts**

Set up alerts when approaching limits:

```bash
# Supabase: Settings → Billing → Usage alerts
# Vercel: Settings → Usage → Set up alerts
```

## Maintenance Schedule

**Daily**
- Check CRON execution logs (06:00 UTC)
- Review error logs for anomalies
- Monitor uptime status

**Weekly**
- Run full verification suite
- Review performance metrics
- Check security logs
- Update dependencies (if patches available)

**Monthly**
- Review cost usage vs limits
- Analyze user feedback/issues
- Audit access logs
- Rotate secrets (quarterly)

**Quarterly**
- Full security audit
- Performance optimization review
- Backup verification test
- Disaster recovery drill

## Disaster Recovery

**Database Backup**

```bash
# Manual backup (Supabase)
supabase db dump -f backup-$(date +%Y%m%d).sql

# Restore from backup
supabase db reset
psql -h db.xxx.supabase.co -U postgres -d postgres -f backup-20250101.sql
```

**Automated Backups**

Supabase provides automatic daily backups on paid plans. For free tier:

```bash
# Add to crontab (daily at 2 AM)
0 2 * * * cd /path/to/repo && supabase db dump -f /backups/backup-$(date +\%Y\%m\%d).sql
```

**Code Repository Backup**

```bash
# Mirror to secondary remote
git remote add backup git@backup-server:truckercore.git
git push backup --all
git push backup --tags
```

## Team Workflows

**Onboarding New Developer**

```bash
# 1. Clone repo
git clone https://github.com/your-org/truckercore.git
cd truckercore

# 2. Install dependencies
npm install

# 3. Set up environment (Windows)
.\scripts\Setup-Environment.ps1 -Save

# Or (Unix/Mac)
cp .env.example .env
# Edit .env with credentials

# 4. Link Supabase
supabase link --project-ref YOUR_REF

# 5. Start dev server
npm run dev

# 6. Run verification
npm run verify:homepage:local
```

**Code Review Checklist**

Before approving PR:
- All tests pass (`npm test`)
- Type check passes (`npm run typecheck`)
- Linting passes (`npm run lint`)
- No console.log/debugger statements
- Security review (no secrets exposed)
- Performance impact assessed
- Documentation updated
- Changelog entry added

## Support & Escalation

**Internal Team**
- Check documentation first (this file + component-specific docs)
- Search existing issues on GitHub
- Ask in Slack #engineering channel
- Create GitHub issue with logs and steps to reproduce

**External Support**
- Supabase: support@supabase.com (paid plans) or Discord
- Vercel: support@vercel.com or help.vercel.com
- Next.js: GitHub Discussions

**Escalation Path**
- P1 (Critical): Site down, data loss
  - Response: Immediate (15 min)
  - Action: Page on-call engineer
- P2 (High): Feature broken, performance degraded
  - Response: 2 hours
  - Action: Slack #incidents channel
- P3 (Medium): Minor bug, slow performance
  - Response: 1 business day
  - Action: Create GitHub issue
- P4 (Low): Enhancement request, documentation
  - Response: Best effort
  - Action: Add to backlog

## Additional Resources

**Documentation**
- Safety Suite Deployment
- Homepage Implementation
- Quick Reference
- Windows Guide
- Asset Guide

**External Links**
- Next.js Docs
- Supabase Docs
- Vercel Docs
- GitHub Actions

**Tools**
- Supabase CLI
- Vercel CLI
- Lighthouse
- axe DevTools

## Changelog

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-09-30 | 1.0.0 | Initial release | Team |

_Last Updated: 2025-09-30_

_Maintained By: TruckerCore Engineering Team_

_Questions?: engineering@truckercore.com_