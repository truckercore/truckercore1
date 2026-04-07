# TruckerCore - Quick Start Deployment Guide

## 🚀 Deploy in 3 Steps

### Step 1: Validate Everything

```powershell
npm run readiness
```

Expected: All checks pass ✓

### Step 2: Deploy to Preview

```powershell
npm run launch
# or
.\launch-deployment.ps1
```

Test the preview URL thoroughly

### Step 3: Deploy to Production

```powershell
npm run launch:prod
# or
.\launch-deployment.ps1 -Environment production
```

Monitor for 15 minutes after deployment

---

## 📋 Complete Workflow

### First Time Setup

```powershell
# 1. Install Vercel CLI
npm install -g vercel

# 2. Login
vercel login

# 3. Link project
vercel link

# 4. Verify setup
npm run check:deploy
```

### Regular Deployment

#### Preview Deployment
```powershell
# Option 1: Interactive (Recommended)
npm run launch

# Option 2: Using deploy script
npm run deploy:preview

# Option 3: Direct Vercel CLI
vercel
```

#### Production Deployment
```powershell
# Option 1: Interactive (Recommended)
npm run launch:prod

# Option 2: Using deploy script
npm run deploy

# Option 3: Direct Vercel CLI
vercel --prod
```

---

## 🔍 Verification Commands

```powershell
# Check if ready to deploy
npm run readiness

# Validate Vercel configuration
npm run validate:vercel

# Verify complete setup
npm run check:deploy

# Check deployment status
npm run status

# View logs
npm run logs
```

---

## 🚨 Emergency Procedures

### Rollback Deployment
```powershell
# Quick rollback
vercel rollback

# Or promote previous deployment
vercel ls
vercel promote <deployment-url>
```

### Fix and Redeploy
```powershell
# 1. Fix the issue locally
# 2. Test build
npm run build

# 3. Commit fix
git add .
git commit -m "Fix: deployment issue"

# 4. Deploy to preview first
npm run launch

# 5. If preview works, deploy to production
npm run launch:prod
```

---

## 📊 Monitoring After Deployment
```powershell
# Watch logs in real-time
npm run logs

# Check status
npm run status

# Verify homepage
npm run verify:homepage:prod

# Check for errors
vercel logs | Select-String "Error"
```

---

## ⚡ Quick Reference

| Command               | Description               |
|-----------------------|---------------------------|
| `npm run readiness`   | Check deployment readiness|
| `npm run launch`      | Deploy to preview         |
| `npm run launch:prod` | Deploy to production      |
| `npm run status`      | Check deployment status   |
| `npm run logs`        | View deployment logs      |
| `npm run check:deploy`| Verify setup              |
| `vercel rollback`     | Rollback deployment       |

---

## 🎯 Common Scenarios

### Scenario 1: First Deployment Ever
```powershell
npm install -g vercel
vercel login
vercel link
npm run check:deploy
npm run launch
```

### Scenario 2: Regular Update
```powershell
git pull
npm install
npm run readiness
npm run launch
# Test preview
npm run launch:prod
```

### Scenario 3: Hotfix
```powershell
# Fix code
npm run build  # Test locally
git add . && git commit -m "Hotfix: issue"
npm run launch:prod  # Deploy directly
npm run logs  # Monitor
```

### Scenario 4: Rollback Needed
```powershell
vercel rollback
npm run status  # Verify
# Fix issue locally
npm run launch  # Test in preview
npm run launch:prod  # Deploy fixed version
```

---

## 💡 Pro Tips

- Always test in preview first
```powershell
npm run launch  # Preview
# Test thoroughly
npm run launch:prod  # Production
```

- Monitor after deployment
```powershell
npm run logs  # Watch for errors
```

- Keep deployments small
  - Deploy frequently
  - Test each change
  - Easy to rollback if needed

- Use the readiness check
```powershell
npm run readiness  # Before every deploy
```

- Save deployment logs
```powershell
npm run logs > deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log
```

---

## 📞 Need Help?
- Check logs: `npm run logs`
- Review status: `npm run status`
- Consult guides:
  - Full guide: docs/VercelDeployment.md
  - Troubleshooting: docs/TROUBLESHOOTING.md
  - Commands: COMMANDS.md

---

## 🚀 Quick Deploy Now
```powershell
npm run readiness && npm run launch
```

Happy Shipping! 🚀
