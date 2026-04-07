# TruckerCore Team Quick Start Guide

## 👋 Welcome to the Team!

This guide will get you from zero to deploying in 15 minutes.

---

## ⚡ 5-Minute Setup

### 1. Clone & Install (2 min)

```bash
# Clone repository
git clone https://github.com/your-org/truckercore1.git
cd truckercore1

# Install dependencies
npm install
```

### 2. Environment Setup (2 min)

```bash
# Copy environment template
cp .env.example .env.local

# Edit with your values
# macOS/Linux: nano .env.local
# Windows (PowerShell): notepad .env.local
```

Required variables:

```bash
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 3. Run Development Server (1 min)

```bash
# Start dev server
npm run dev

# Open browser
# macOS: open http://localhost:3000
# Windows: start http://localhost:3000
# Linux: xdg-open http://localhost:3000
```

✅ You should see the TruckerCore homepage!

---

## 🚀 Your First Deployment (10 min)

### Prerequisites

Install required tools:

```bash
# Vercel CLI
npm install -g vercel

# Supabase CLI
# macOS (Homebrew):
brew install supabase/tap/supabase
# Others: https://supabase.com/docs/guides/cli

# Login to both
vercel login
supabase login
```

### Deploy to Production

```bash
# Check if you're ready
npm run check:status

# Deploy!
npm run deploy
```

That's it! 🎉

---

## 📚 Common Tasks

### Development

```bash
npm run dev          # Start dev server
npm run test:unit    # Run unit tests
npm run typecheck    # TypeScript check
npm run validate:seo # Validate page meta tags & assets
```

### Deployment

```bash
npm run deploy          # Full deployment (recommended)
npm run deploy:fast     # Quick deployment (skip tests)
npm run check:production # Verify production health
```

### Monitoring

```bash
npm run monitor      # Live status dashboard
npm run monitor:logs # Follow logs
npm run quick-ref    # Show all commands
```

### Troubleshooting

```bash
npm run check:debug # Debug 404 issues
npm run check:dns   # Check DNS configuration
npm run check:status # Verify deployment readiness
```

---

## 🎯 Daily Workflow

### Making Changes

```bash
# 1. Create feature branch
git checkout -b feature/your-feature

# 2. Make changes
# ... edit code ...

# 3. Test locally
npm run dev
npm run test:unit

# 4. Commit
git add .
git commit -m "feat: your feature description"

# 5. Push
git push origin feature/your-feature

# 6. Create PR on GitHub
```

### Deploying to Production

```bash
# 1. Merge PR to main branch

# 2. Pull latest
git checkout main
git pull origin main

# 3. Check readiness
npm run check:status

# 4. Deploy
npm run deploy

# 5. Monitor
npm run monitor
```

---

## 🆘 Getting Help

Documentation

- Quick Reference: `npm run quick-ref`
- Deployment Guide: `docs/DEPLOYMENT_TRAINING.md`
- Launch Runbook: `LAUNCH_DAY_RUNBOOK.md` (if present)
- DNS Setup: `docs/DNS_CONFIGURATION.md`

Team Channels

- #engineering — General questions
- #incidents — Production issues
- #deployments — Deployment notifications

Emergency Contacts

- On-call Engineer: [Name] — [Phone]
- Tech Lead: [Name] — [Email]
- DevOps: [Name] — [Slack]

---

## 🎓 Learning Path

Week 1: Basics

- Clone repo and run locally
- Understand project structure
- Make a small PR (docs/typo fix)
- Review deployment workflow

Week 2: Development

- Implement a small feature
- Write unit tests
- Submit PR for review
- Deploy to staging

Week 3: Deployment

- Deploy to production (supervised)
- Monitor deployment
- Respond to an incident (simulated)

Week 4: Independence

- Deploy independently
- Fix production bug
- Improve documentation

---

## ✅ Onboarding Checklist

Access

- GitHub repository access
- Vercel project access
- Supabase project access
- Sentry access
- Slack channels joined

Tools

- Node.js 20+ installed
- Git configured
- Vercel CLI installed
- Supabase CLI installed
- IDE setup (VSCode recommended)

Knowledge

- Read README.md
- Read `docs/DEPLOYMENT_TRAINING.md`
- Watched demo video (if available)
- Completed Week 1 learning path

First Tasks

- Run dev server locally
- Make first commit (docs improvement)
- Submit first PR
- Attend team standup
- Shadow a deployment

---

## 🎉 You're Ready!

You now know enough to:

- Develop features locally
- Run tests and validations
- Deploy to production
- Monitor and troubleshoot

Welcome to the team! Let's build something amazing together. 🚀

Questions? Ask in #engineering or DM your onboarding buddy!