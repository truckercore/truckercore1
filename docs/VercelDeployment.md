# TruckerCore Vercel Deployment Guide

## Prerequisites

- Node.js 18.x (18.20.4 recommended)
- npm >= 9.0.0
- Vercel CLI: `npm i -g vercel`
- Git repository connected to Vercel

## Deployment Checklist

### 1. Pre-Deployment Verification

Run the pre-deployment check script:

```powershell
powershell .\vercel-deploy-check.ps1
```

This verifies:
- ✓ Vercel CLI installation
- ✓ package.json configuration
- ✓ vercel.json exists and valid
- ✓ Clean install works
- ✓ No legacy json2csv v6
- ✓ Production build succeeds

### 2. Manual Deployment

```powershell
# Preview deployment (non-production)
vercel

# Production deployment
vercel --prod

# With specific environment
vercel --prod --env production
```

### 3. Auto-Deployment via Git

```powershell
# Commit changes
git add .
git commit -m "Your commit message"

# Push to trigger auto-deployment
git push origin main # or master
```

### 4. Monitor Deployment

```powershell
# Check deployment status
.\check-vercel-deployment.ps1

# View live logs
vercel logs --follow

# View logs for specific deployment
vercel logs <deployment-url>
```

## Configuration Files

### vercel.json

```json
{
  "buildCommand": "npm run build",
  "installCommand": "npm ci --legacy-peer-deps",
  "framework": "nextjs",
  "regions": ["iad1"],
  "env": {
    "NODE_VERSION": "18.20.4"
  },
  "build": {
    "env": {
      "NODE_OPTIONS": "--max-old-space-size=4096"
    }
  }
}
```

### package.json (Key Settings)

```json
{
  "engines": {
    "node": ">=18.0.0 <21.0.0",
    "npm": ">=9.0.0"
  },
  "dependencies": {
    "@json2csv/plainjs": "^7.0.6"
  },
  "overrides": {
    "jose": "^4.15.5",
    "json2csv": "npm:@json2csv/plainjs@^7.0.6"
  }
}
```

## Troubleshooting

### Build Fails on Vercel

1. Check build logs:
   ```powershell
   vercel logs <deployment-url>
   ```

2. Common issues:
   - Memory issues: Already handled with `--max-old-space-size=4096`
   - Dependency conflicts: Resolved with overrides and `--legacy-peer-deps`
   - Environment variables: Verify in Vercel dashboard

### Dependency Issues

If json2csv errors appear:

```powershell
# Run full diagnostic
.\run-diagnostics.ps1

# Check for v6 references
npm ls json2csv --all

# Force clean reinstall
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

### Deployment Stuck or Failed

1. Cancel current deployment:
   ```bash
   vercel rollback
   ```

2. Redeploy:
   ```powershell
   vercel --prod --force
   ```

## Environment Variables

Set these in Vercel Dashboard (Project Settings → Environment Variables):

- NODE_VERSION: 18.20.4
- NODE_OPTIONS: --max-old-space-size=4096
- Add any API keys or secrets your app needs

## Post-Deployment Verification

1. Check deployment URL:
   - Visit the provided URL
   - Test critical functionality

2. Monitor logs for errors:
   ```powershell
   vercel logs --follow
   ```

3. Test production build locally:
   ```powershell
   npm run build
   npm run start
   ```

## Rollback Procedure

If deployment has issues:

```bash
# List recent deployments
vercel ls

# Rollback to previous deployment
vercel rollback [deployment-url]

# Or promote a specific deployment to production
vercel promote [deployment-url]
```

## Best Practices

1. Always run pre-check before deploying:
   ```powershell
   .\vercel-deploy-check.ps1
   ```

2. Test locally first:
   ```powershell
   npm run build && npm run start
   ```

3. Use preview deployments for testing:
   ```powershell
   vercel  # Creates preview deployment
   ```

4. Monitor first few minutes after deployment:
   ```powershell
   vercel logs --follow
   ```

5. Keep dependencies updated:
   ```powershell
   npm outdated
   npm update
   ```

## Support

- Vercel Dashboard: https://vercel.com/dashboard
- Vercel Docs: https://vercel.com/docs
- Project Logs: `vercel logs`

---

## Quick Reference Scripts

Create a master script that runs everything in sequence (already added as `deploy.ps1` in repo root):

```powershell
.\deploy.ps1 [-SkipDiagnostics] [-SkipPreCheck] [-PreviewOnly] [-Force]
```

Examples:

```powershell
# Full deployment with all checks
.\deploy.ps1

# Deploy to preview environment
.\deploy.ps1 -PreviewOnly

# Quick deployment skipping diagnostics but forcing continue on warnings
.\deploy.ps1 -SkipDiagnostics -Force
```

CI/CD Integration (Optional) – see the repository README or your platform docs for how to add the provided GitHub Actions workflow example.
