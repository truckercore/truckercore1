# 🚢 Ship Command - Deploy to Production

## Quick Start

```bash
npm run ship
```

That's it! This single command handles everything:
- ✅ Verifies DNS configuration
- ✅ Checks deployment readiness
- ✅ Runs all tests
- ✅ Builds production bundle
- ✅ Deploys to Vercel
- ✅ Verifies deployment
- ✅ Shows celebration 🎉

---

## Ship Variants

### Standard Ship (Recommended)

```bash
npm run ship
```
What it does:
- Complete pre-flight checks
- Full test suite
- Production build
- Deploy
- Verify
- Celebrate

Time: ~5 minutes  
Safety: 🛡️ Maximum

---

### Fast Ship (Use Carefully)

```bash
npm run ship:fast
```
What it does:
- Skips test suite
- Quick build
- Deploy
- Basic verification

Time: ~2 minutes  
Safety: ⚠️ Moderate  
When to use: Hotfixes, minor updates

---

### Instant Ship (CI/CD)

```bash
npm run ship:now
```
What it does:
- Pre-flight checks
- Deploy immediately
- No prompts

Time: ~3 minutes  
Safety: 🛡️ Good  
When to use: Automated deployments

---

## Before You Ship

### Pre-Flight Checklist

```bash
# 1. Check status
npm run check:status

# 2. Verify DNS
npm run dns:check

# 3. Run tests locally
npm run test:unit

# 4. Build test
npm run build
```

All should pass ✅

---

## After You Ship

### Immediate Verification (Automated)

The ship command automatically runs:

```bash
npm run check:production
```

You should see:

```
Results: 21/21 checks passed
✅ All checks passed! Production is healthy.
```

### Manual Verification

```bash
# 1. Check homepage
curl -I https://truckercore.com
# Expected: HTTP/2 200

# 2. Check app
curl -I https://app.truckercore.com
# Expected: HTTP/2 200

# 3. Check API health
curl https://api.truckercore.com/health | jq
# Expected: {"status":"healthy",...}
```

### Monitor for 30 Minutes

```bash
npm run monitor
```

Watch for:
- ✅ All domains return 200
- ✅ Response times < 2s
- ✅ No errors in logs

---

## Troubleshooting

### Ship Failed During Build

Symptoms:
```
❌ Build failed
```

Fix:
```bash
npm run typecheck
npm run lint
npm run ship
```

### Ship Failed During Tests

Symptoms:
```
⚠️ Some tests failed
```

Options:
1. Fix tests, then re-ship: `npm run ship`
2. Skip tests (if urgent): `npm run ship:fast`

### Site Returns 404 After Shipping

Symptoms:
- Domain resolves but returns 404

Diagnosis:
```bash
vercel ls
npm run monitor:logs
```

Common causes: deployment in progress, build failed, route configuration issue. Fix and re-verify.

### SSL Certificate Warning

Cause: Vercel still provisioning SSL (5–10 minutes). Wait and retry.

---

## Ship Metrics

Success criteria after shipping:

| Metric | Target | Command |
|--------|--------|---------|
| Uptime | 100% | `npm run monitor` |
| Response Time | < 2s | `npm run check:production` |
| Error Rate | < 0.1% | Check Sentry |
| Lighthouse Score | ≥ 90 | `lighthouse https://truckercore.com` |

---

## Emergency Rollback

```bash
git revert HEAD
git push origin main
# Or via Vercel dashboard → Promote previous deployment
```

---

## Ship Notifications

In Slack (#deployments):
```
🚢 TruckerCore shipped to production!
✅ All checks passed
📊 Deployment time: 4m 32s
🌐 Live: https://truckercore.com
Monitoring for next 30 minutes.
```

---

## Ship History

Track your ships in SHIP_LOG.md.

---

## Final Ship Checklist

Before running `npm run ship`:

- [ ] All changes committed and on `main`
- [ ] `npm run typecheck` passes
- [ ] `npm run test:unit` passes
- [ ] `npm run build` succeeds
- [ ] `npm run dns:check` passes
- [ ] `npm run deploy:preflight` passes
- [ ] On-call and monitoring ready

When all boxes are checked, run:

```bash
npm run ship
```

Then sit back and watch the magic happen! ✨
