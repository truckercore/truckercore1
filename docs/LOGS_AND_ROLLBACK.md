# Operations: Logs and Rollback

This guide summarizes the essential commands to tail logs during incidents and execute a safe rollback if needed.

---

## Logs to Check

```bash
# Vercel function logs (follow live)
vercel logs --follow

# Supabase Edge Function logs
supabase functions logs refresh-safety-summary

# Database query performance
# Check slow query log in Supabase dashboard (Project → Database → Logs)
```

Tips:
- Use filters/time ranges in both Vercel and Supabase dashboards to narrow down incidents.
- For the Edge Function, also try: `supabase functions logs refresh-safety-summary --tail 100`.

---

## 🆘 Rollback Procedure (If Needed)

If critical issues arise, choose one of the options below.

```bash
# Option 1: Revert via Git (fast-forward rollback)
git revert HEAD
git push origin main
# Vercel auto-deploys the previous version

# Option 2: Rollback via Vercel Dashboard
# Visit your Vercel project → Deployments → Find last good deployment → "Promote to Production"

# Option 3: Disable new features via flags (soft rollback)
npm run rollout:flags -- --disable safety_summary,risk_corridors
```

Notes:
- After rollback, run your verification suite and monitoring:
  - `npm run verify:all`
  - `npm run test:integration`
  - Check dashboards (Vercel/Supabase) and error trackers.
- Consider unscheduling CRON temporarily if the issue relates to the daily refresh job:

```bash
supabase functions unschedule refresh-safety-summary
```

---

## Helpful npm scripts

These aliases are available once you pull the latest repository version:

```bash
# Logs
npm run logs:vercel          # vercel logs --follow
npm run logs:ef              # supabase functions logs refresh-safety-summary

# Rollback
npm run rollback:git         # git revert HEAD && git push origin main
npm run rollback:disable-features  # disable safety_summary, risk_corridors flags
```

For more comprehensive procedures, see:
- docs/LAUNCH_PLAYBOOK.md (Monitoring and Rollback sections)
- docs/POST_LAUNCH_MONITORING.md
- ./.deployment-ready
