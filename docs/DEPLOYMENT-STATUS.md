# Deployment Infrastructure Status

This document summarizes the deployment infrastructure for TruckerCore (web) and where to find the key scripts and configs.

## Overview
- Platform: Vercel (Next.js)
- Node: 18.x (18.20.4 configured)
- Memory tweak: NODE_OPTIONS=--max-old-space-size=4096 for builds
- Region: iad1

## Key Files
- vercel.json — Vercel configuration (build/install commands, env, regions, headers, rewrites, crons)
- package.json — npm scripts and dependency configuration
- verify-deployment-setup.ps1 — Full setup verification script
- vercel-deploy-check.ps1 — Pre-deployment check (6 steps)
- deploy.ps1 — Interactive deployment workflow (preview or production)
- check-vercel-deployment.ps1 — Latest deployment status (wrapper around vercel-check-status.ps1)

## How to Operate
- Verify setup: `./verify-deployment-setup.ps1` or `npm run check:deploy`
- Deploy (production): `./deploy.ps1` or `npm run deploy`
- Deploy (preview): `./deploy.ps1 -PreviewOnly` or `npm run deploy:preview`
- Check status: `./check-vercel-deployment.ps1` or `npm run status`
- View logs: `vercel logs --follow` or `npm run logs`

## Environment Variables (Vercel Dashboard)
- NODE_VERSION = 18.20.4
- NODE_OPTIONS = --max-old-space-size=4096
- Any project secrets (API keys, etc.)

## Success Criteria
- Build succeeds locally and on Vercel
- No legacy json2csv v6 present
- App boots without console errors
- API routes respond as expected

## References
- Full deployment guide: docs/VercelDeployment.md
- Quick reference: docs/QUICK-REFERENCE.md
- Troubleshooting: docs/TROUBLESHOOTING.md (or root TROUBLESHOOTING.md)
