# TruckerCore - Command Reference

## 🚀 Quick Deploy

```powershell
# Complete deployment (recommended)
.\deploy.ps1

# Preview only
.\deploy.ps1 -PreviewOnly

# Skip diagnostics (faster)
.\deploy.ps1 -SkipDiagnostics

# Using npm
npm run deploy      # Production
npm run deploy:preview  # Preview
```

## 🔍 Verification & Diagnostics

```powershell
# Final readiness check (run before deploy)
.\deploy-readiness.ps1

# Complete system diagnostic
.\run-diagnostics.ps1

# Pre-deployment verification
.\vercel-deploy-check.ps1

# Setup verification
.\verify-deployment-setup.ps1

# Check deployment status
.\check-vercel-deployment.ps1

# Using npm
npm run check:deploy   # Verify setup
npm run diagnose       # Run diagnostics
npm run status         # Check deployment
npm run readiness      # Final readiness check
```

## 📦 Dependency Management

```powershell
# Install dependencies
npm install

# Clean reinstall
npm run clean
npm install

# Fresh install (complete cleanup)
npm run fresh

# Check specific dependencies
npm run check:deps

# Check for updates
npm outdated

# Security audit
npm audit
npm audit fix
```

## 🏗️ Build & Development

```powershell
# Development server
npm run dev

# Production build
npm run build

# Start production server
npm run start

# Lint code
npm run lint

# Run tests
npm test
```

## 📊 Monitoring & Logs

```powershell
# View live logs
npm run logs
# or
vercel logs --follow

# View specific deployment logs
vercel logs <deployment-url>

# Check current status
npm run status

# List all deployments
vercel ls

# Inspect deployment
vercel inspect <deployment-url>
```

## 🔄 Deployment Management

```powershell
# Deploy to production
vercel --prod

# Deploy to preview
vercel

# Force redeploy
vercel --prod --force

# Rollback
vercel rollback

# Promote deployment to production
vercel promote <deployment-url>

# Alias deployment
vercel alias <deployment-url>
```

## 🌍 Environment Variables

```powershell
# List environment variables
vercel env ls

# Add environment variable
vercel env add

# Remove environment variable
vercel env rm

# Pull environment variables locally
vercel env pull .env.local
```

## 🔗 Project Management

```powershell
# Login to Vercel
vercel login

# Link project
vercel link

# Get project info
vercel project ls

# Switch project
vercel switch
```

## 🧹 Cleanup

```powershell
# Clean build artifacts
npm run clean

# Clean cache
npm cache clean --force
npm cache verify

# Remove specific files
Remove-Item -Recurse -Force node_modules
Remove-Item -Force package-lock.json
Remove-Item -Recurse -Force .next
Remove-Item -Recurse -Force .vercel
```

## 🚨 Emergency

```powershell
# Immediate rollback
vercel rollback

# Force stop and redeploy
# 1. Cancel current deployment (Ctrl+C in terminal)
# 2. Check status
vercel ls
# 3. Redeploy
.\deploy.ps1 -Force

# Get help
vercel help
```

## 📚 Documentation

```powershell
# View quick reference
Get-Content docs/QUICK-REFERENCE.md

# View troubleshooting guide
Get-Content docs/TROUBLESHOOTING.md

# View deployment guide
Get-Content docs/VercelDeployment.md

# View this file
Get-Content COMMANDS.md
```

## 🎯 Common Workflows

### First Time Setup

```powershell
npm install
.\verify-deployment-setup.ps1
vercel login
vercel link
.\deploy-readiness.ps1
```

### Regular Deployment

```powershell
git add .
git commit -m "Your message"
.\deploy-readiness.ps1
.\deploy.ps1 -PreviewOnly
# Test preview
.\deploy.ps1
```

### Troubleshooting

```powershell
npm run diagnose
npm run logs
.\verify-deployment-setup.ps1
# Fix issues
npm run fresh
npm run build
```

### Emergency Rollback

```powershell
vercel rollback
vercel ls  # Verify
# Fix issues locally
.\deploy.ps1 -PreviewOnly
# Test thoroughly
.\deploy.ps1
```

---

💡 Tip: Add this directory to your PATH for easier access:

```powershell
$env:PATH += ";$(Get-Location)"
```

📌 Bookmark: Keep this file open for quick reference during deployments.
