# TruckerCore Deployment Guide (Final Readiness)

This guide summarizes the final steps to validate and deploy TruckerCore to Vercel.

## 1) Run the final comprehensive check

```powershell
./final-deployment-check.ps1
```

- Runs validations for dependencies, workflows, git status, Vercel config, a production build test, and presence of key scripts and docs.
- Exit code 0 = Ready; non‑zero = Fix issues noted in the output.

## 2) If all passes, commit any remaining changes

```powershell
git status
git add .
git commit -m "chore: Final deployment preparation - workflows fixed, code cleaned"
```

## 3) Deploy

- Interactive preview/production via launcher:

```powershell
npm run launch          # Preview (interactive)
npm run launch:prod     # Production (interactive)
```

- Or use the underlying scripts:

```powershell
./validate-for-vercel.ps1
./deploy-readiness.ps1 -Verbose
./launch-deployment.ps1 -Environment production
```

## 4) Monitor deployment

```powershell
npm run logs      # vercel logs --follow
npm run status    # check latest deployment
```

---

## Reference scripts

- final-deployment-check.ps1  – Final comprehensive check before deploying
- validate-for-vercel.ps1     – Validate @json2csv/plainjs, overrides, types, build
- deploy-readiness.ps1        – Deep readiness validation and summary
- verify-deployment-setup.ps1 – Setup verification (files, env, config)
- launch-deployment.ps1       – Interactive end‑to‑end deploy (preview/production)
- deployment-dashboard.ps1    – Visual status dashboard (auto-refresh)

## Configuration expectations

- vercel.json
  - buildCommand: npm run build
  - installCommand: npm ci --legacy-peer-deps
  - env.NODE_VERSION: 18.20.4
  - build.env.NODE_OPTIONS: --max-old-space-size=4096
- package.json
  - @json2csv/plainjs: ^7.x
  - overrides.json2csv → npm:@json2csv/plainjs@^7.x
  - engines.node: >=18 <21; engines.npm: >=9

## Quick troubleshooting

- Build fails: `npm run diagnose` and inspect the last lines of the build output.
- Missing types: `./fix-build-types.ps1`
- Legacy json2csv v6 references: `npm run fresh` (clean install)
- Disabled Flutter workflow: `.github/workflows/flutter-desktop.yml` is disabled by design.

## Final commands (quick)

```powershell
./final-deployment-check.ps1
# If green:
git add . && git commit -m "chore: final deployment prep" && git push
npm run launch
```

## Optional PWA (Progressive Web App)

PWA support is optional and gated by an environment variable to make CI/Vercel builds predictable.

- To enable PWA for the web app, set an environment variable:
  - ENABLE_PWA=true
- Where to set it on Vercel:
  - Project Settings → Environment Variables → Add ENABLE_PWA with value true (Scope: Production/Preview as needed).
- Ensure dependencies are installed for the apps/web workspace so `next-pwa` is available during build:
  - This repo’s vercel.json already runs install in `apps/web` and builds from there.
  - Alternatively, set Vercel Root Directory to `apps/web`, or override Install/Build commands to target `apps/web`.

Notes
- When ENABLE_PWA is not set (or false), the build proceeds without PWA — no service worker is generated/registered.
- In development (NODE_ENV=development), service worker is avoided even if ENABLE_PWA=true.
- If you prefer strict CI (fail when PWA is enabled but deps are missing), ensure your monorepo/workspace install always provides `next-pwa` and consider removing the guard in `apps/web/next.config.js`.
