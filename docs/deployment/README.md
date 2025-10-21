# TruckerCore Safety Summary Suite - Deployment Guide

## Overview

Automated deployment system for the Safety Summary Suite, supporting Windows, Unix/Linux, and macOS environments.

## What Gets Deployed

1. Database Schema: Tables, views, indexes, RLS policies
2. Edge Functions: CRON-scheduled safety summary refresh
3. API Routes: CSV export endpoint
4. UI Components: Dashboard cards and reports

## Prerequisites

- Node.js 18+
- Supabase CLI (`npm install -g supabase`)
- Supabase project with environment variables configured

## Quick Start

Choose your platform:

### Windows

powershell
# Setup (once)
.\scripts\Setup-Environment.ps1 -Save
supabase link --project-ref YOUR_REF

# Deploy
npm run deploy:safety-suite:win

# Verify
npm run verify:safety-suite:win

### Unix/Linux/macOS

bash
# Setup (once)
export SUPABASE_URL="https://xxx.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
supabase link --project-ref YOUR_REF

# Deploy
npm run deploy:safety-suite

# Verify
npm run verify:safety-suite

## Documentation

- Deployment Summary - Complete deployment details (`docs/deployment/DEPLOYMENT_SUMMARY.md`)
- Windows Guide - Windows-specific instructions (`docs/deployment/windows-deployment.md`)
- Quick Reference - Command cheat sheet (`docs/deployment/QUICK_REFERENCE.md`)
- Safety Summary Checklist - Deployment checklist (`docs/deployment/safety-summary-checklist.md`)

## Support

For issues:
- Check Troubleshooting
- Review logs: `supabase functions logs refresh-safety-summary`
- Run verification: `npm run verify:safety-suite[:win]`
- Open GitHub issue with logs

## License

Proprietary - TruckerCore
