# Vercel Deployment Guide

This repository is configured for deployment on Vercel using a monorepo layout where the Next.js app lives in `apps/web`.

## Prerequisites
- Node.js 20+
- Vercel CLI installed
- Access to the Vercel project and dashboard

## One-time Setup

1. Install Vercel CLI
```bash
npm install -g vercel
```

2. Login to Vercel
```bash
vercel login
```

3. Link local project to a Vercel project (if not already linked)
```bash
# Run at the repo root (will detect monorepo via vercel.json)
vercel
```
- When prompted, select the scope and project.
- Vercel will use the provided `vercel.json` which targets `apps/web`.

## Environment Variables (set in Vercel Dashboard)
Configure the following environment variables for the project (Settings → Environment Variables):

```
NODE_ENV=production
NEXT_PUBLIC_APP_URL=https://your-domain.com
DATABASE_URL=your_database_url
FMCSA_API_KEY=your_fmcsa_key
```

Set variables for both Preview and Production environments as needed.

## Deployments

### Deploy to Staging (Preview)
```bash
vercel
```
- This creates a Preview deployment. Visit the generated URL and verify functionality.

### Deploy to Production
```bash
vercel --prod
```
- After verifying staging, promote to production with the above command.

### Domains
Add your custom domain to the Vercel project:
```bash
vercel domains add your-domain.com
```
Then configure your DNS per Vercel instructions.

## Notes on Monorepo Configuration
- The root `vercel.json` contains:
  - `builds` entry pointing to `apps/web/package.json` using `@vercel/next`.
  - Security headers and a sample rewrite path for public file downloads.
  - Scheduled functions (crons) paths at `/api/...` which should correspond to Next.js Route Handlers under `apps/web/src/app/api`.
- The build/install commands are handled by the Vercel builder; no custom `buildCommand` is required.

## Local Verification
```bash
# From apps/web
cd apps/web
npm install
npm run dev
# Open http://localhost:3000
```

## Troubleshooting
- If Vercel tries to build from repo root, ensure `vercel.json` exists at the root and includes the `builds` section pointing to `apps/web/package.json`.
- Ensure the Next.js pages and routes exist: `/`, `/freight-broker-dashboard`, `/owner-operator-dashboard`, `/fleet-manager-dashboard`.
- Check the logs in Vercel Dashboard for build/runtime errors.
- Verify environment variables are set for both Preview and Production.

## Security
- Do not commit secrets to the repo.
- Use Vercel Project Settings to store secrets.
