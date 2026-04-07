# TruckerCore Deployment - Quick Reference

## 🚀 Common Commands

### Deploy to Production

```powershell
./deploy.ps1
```

### Deploy to Preview

```powershell
./deploy.ps1 -PreviewOnly
```

### Quick Deploy (Skip Diagnostics)

```powershell
./deploy.ps1 -SkipDiagnostics
```

### Force Deploy (Ignore Warnings)

```powershell
./deploy.ps1 -Force
```

---

## 🔍 Diagnostics & Checks

### Full System Diagnostic

```powershell
./run-diagnostics.ps1
```

### Pre-Deployment Check

```powershell
./vercel-deploy-check.ps1
```

### Verify Deployment Setup

```powershell
./verify-deployment-setup.ps1
```

### Check Deployment Status

```powershell
./check-vercel-deployment.ps1
```

---

## 🛠️ Troubleshooting

### Clean Reinstall

```powershell
# Windows PowerShell
rimraf node_modules package-lock.json .next .vercel
npm cache clean --force
npm install
```

### Check for Legacy Dependencies

```powershell
npm ls json2csv --all
```

### View Build Logs

```powershell
vercel logs <deployment-url>
# or
vercel logs --follow
```

### Rollback Deployment

```powershell
vercel rollback <deployment-url>
```

---

## 📦 Manual Vercel Commands

### Login to Vercel

```powershell
vercel login
```

### Link Project

```powershell
vercel link
```

Deploy Preview

```powershell
vercel
```

Deploy Production

```powershell
vercel --prod
```

List Deployments

```powershell
vercel ls
```

View Environment Variables

```powershell
vercel env ls
```

Pull Environment Variables

```powershell
vercel env pull
```

---

## 🔧 Local Development

Install Dependencies

```powershell
npm install
```

Run Development Server

```powershell
npm run dev
```

Build Production

```powershell
npm run build
```

Start Production Server

```powershell
npm run start
```

Run Tests

```powershell
npm test
```

---

## 📊 File Locations

| File | Purpose |
|------|---------|
| deploy.ps1 | Main deployment script |
| run-diagnostics.ps1 | Full system diagnostic |
| vercel-deploy-check.ps1 | Pre-deployment verification |
| check-vercel-deployment.ps1 | Deployment status checker |
| verify-deployment-setup.ps1 | Setup verification |
| vercel.json | Vercel configuration |
| package.json | Dependencies & scripts |
| docs/VercelDeployment.md | Full deployment guide |
| docs/QUICK-REFERENCE.md | This file |

---

## ⚡ Emergency Procedures

Build Failing on Vercel

- Check logs: `vercel logs <url>`
- Run local diagnostics: `./run-diagnostics.ps1`
- Verify setup: `./verify-deployment-setup.ps1`
- Fix issues and redeploy

Dependency Conflicts

- Clean install: `rimraf node_modules package-lock.json .next .vercel && npm install`
- Check for v6: `npm ls json2csv --all`
- Verify overrides in package.json

Deployment Stuck

- Cancel: Ctrl+C in terminal
- Check status: `vercel ls`
- Force redeploy: `vercel --prod --force`

Production Down

- Immediate rollback: `vercel rollback`
- Check previous deployments: `vercel ls`
- Promote working deployment: `vercel promote <url>`

---

## 🎯 Deployment Checklist

1. Run `./verify-deployment-setup.ps1`
2. Commit changes: `git add . && git commit -m "..."`
3. Run `./deploy.ps1`
4. Check deployment: `./check-vercel-deployment.ps1`
5. Test the deployed app
6. Monitor logs: `vercel logs --follow`

---

## 📞 Support Resources

- Vercel Dashboard: https://vercel.com/dashboard
- Vercel Docs: https://vercel.com/docs
- Project Logs: `vercel logs`
- Vercel Status: https://vercel-status.com

---

## 🔐 Environment Variables to Set

Set these in Vercel Dashboard → Project Settings → Environment Variables:

| Variable | Value | Environment |
|----------|-------|-------------|
| NODE_VERSION | 18.20.4 | All |
| NODE_OPTIONS | --max-old-space-size=4096 | All |
| (Add your API keys here) |  |  |


Last Updated: 