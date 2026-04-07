# TruckerCore Launch Playbook

## 🚀 Launch Day Checklist

**Date:** ___________  
**Launch Time:** ___________  
**On-Call Engineer:** ___________  
**Backup Engineer:** ___________

---

## T-24 Hours (Day Before Launch)

### Preparation
- [ ] **Run pre-flight check**
  ```bash
  npm run preflight
  ```
- [ ] **Final code review**
  - All PRs merged
  - No open critical issues
  - Documentation complete

- [ ] **Communication**
  - [ ] Notify team in Slack
  - [ ] Update status page (if applicable)
  - [ ] Prepare rollback plan

- [ ] **Backups**
  - [ ] Database backup taken
  - [ ] Git tag created: `git tag -a v1.2.0 -m "Launch v1.2.0"`
  - [ ] Environment variables documented

- [ ] **Dry run**
  - [ ] Deploy to staging
  - [ ] Run full test suite
  - [ ] Verify rollback works

---

## T-2 Hours (Launch Window Opens)

### Final Checks
- [ ] **Team readiness**
  - [ ] All engineers available
  - [ ] Communication channels open
  - [ ] Monitoring dashboards ready

- [ ] **Environment check**
  ```bash
  npm run preflight
  ```

- [ ] **Dependencies updated**
  ```bash
  npm audit
  npm outdated
  ```

---

## T-0: Launch Execution

### Phase 1: Database (15 minutes)

**Step 1.1: Deploy Migration**
```

bash
Run pre-flight
npm run preflight
Deploy Safety Suite (includes migration)
npm run deploy:safety-suite # or deploy:safety-suite:win on Windows``` 

**Verification:**
```

bash
Verify tables created
npm run verify:safety-suite
Manual check
supabase db pull
Should show new tables: safety_daily_summary, risk_corridor_cells``` 

**✅ Checkpoint:** All tables exist with correct schema

**Step 1.2: Test RPC Function**
```

bash
Test manually via Supabase dashboard or:
curl -X POST "SUPABASE_URL/rest/v1/rpc/refresh_safety_summary" \ -H "apikey:SERVICE_KEY"
-H "Authorization: Bearer $SERVICE_KEY"
-H "Content-Type: application/json"
-d '{"p_org":null,"p_days":7}'``` 

**✅ Checkpoint:** RPC executes without errors (<10s)

---

### Phase 2: Edge Functions (10 minutes)

**Step 2.1: Verify Deployment**
```

bash
Should be deployed by deploy:safety-suite, verify:
supabase functions list
Should show: refresh-safety-summary``` 

**Step 2.2: Set Secrets**
```

bash supabase secrets set SUPABASE_SERVICE_ROLE_KEY="SUPABASE_SERVICE_ROLE_KEY" supabase secrets set SUPABASE_URL="SUPABASE_URL"
Verify
supabase secrets list``` 

**Step 2.3: Test Invocation**
```

bash curl -X POST "SUPABASE_URL/functions/v1/refresh-safety-summary" \ -H "Authorization: BearerSERVICE_KEY"
Should return: {"success":true,"timestamp":"..."}``` 

**✅ Checkpoint:** Edge Function responds successfully

**Step 2.4: Schedule CRON**
```

bash supabase functions schedule refresh-safety-summary "0 6 * * *"
Verify
supabase functions list
Should show: [scheduled: 0 6 * * *]``` 

**✅ Checkpoint:** CRON scheduled for daily 06:00 UTC

---

### Phase 3: Homepage (5 minutes)

**Step 3.1: Final Asset Check**
```

bash npm run check:homepage-assets``` 

**Action if missing assets:**
- Use placeholders for now
- Plan to replace within 7 days

**Step 3.2: Deploy**
```

bash
Ensure on main branch
git checkout main git pull origin main
Deploy (triggers Vercel auto-deploy)
git push origin main``` 

**Step 3.3: Monitor Deployment**
- Watch Vercel dashboard: https://vercel.com/dashboard
- Deployment typically takes 2-3 minutes
- Wait for "Ready" status

**✅ Checkpoint:** Vercel shows "Ready" status

**Step 3.4: Verify Homepage**
```

bash
Wait 30 seconds for DNS propagation, then:
npm run verify:homepage:prod``` 

**Manual checks:**
- [ ] Visit https://truckercore.com
- [ ] All sections load (hero, features, use cases, CTA, footer)
- [ ] "Launch App" button links to app.truckercore.com
- [ ] "Learn More" scrolls to #features
- [ ] Mobile responsive (test on phone)

**✅ Checkpoint:** Homepage accessible and functional

---

### Phase 4: Integration Verification (10 minutes)

**Step 4.1: Run Full Test Suite**
```

bash npm run verify:all npm run test:integration``` 

**Expected Results:**
- All verification tests pass
- Integration tests: 20-25 tests pass
- Zero critical failures

**✅ Checkpoint:** All tests green

**Step 4.2: Manual Smoke Tests**

**Safety Suite:**
- [ ] CSV export works: `curl "https://truckercore.com/api/export-alerts.csv?org_id=test"`
- [ ] Edge Function responds
- [ ] Database queries fast (<1s)

**Homepage:**
- [ ] Sitemap: https://truckercore.com/sitemap.xml
- [ ] Robots: https://truckercore.com/robots.txt
- [ ] 404 page: https://truckercore.com/nonexistent-page
- [ ] Social sharing (test on Twitter/LinkedIn)

**✅ Checkpoint:** All smoke tests pass

---

## T+15 minutes: Monitoring Setup

### Step 5.1: Verify Monitoring Active

**Vercel:**
- [ ] Visit https://vercel.com/dashboard/analytics
- [ ] Analytics enabled
- [ ] No errors in logs

**Supabase:**
- [ ] Visit https://app.supabase.com/project/YOUR_REF
- [ ] Database healthy (CPU < 50%, connections < 20)
- [ ] No errors in logs
- [ ] Edge Function shows recent invocation

**GitHub Actions:**
- [ ] Visit https://github.com/your-org/truckercore/actions
- [ ] Latest workflow run successful
- [ ] Hourly verification enabled

**✅ Checkpoint:** All monitoring systems active

### Step 5.2: Set Up Alerts

- [ ] Vercel alerts configured (deployment failures, high error rate)
- [ ] GitHub Actions Slack notifications enabled
- [ ] Uptime monitor active (UptimeRobot or similar)

---

## T+30 minutes: First Hour Monitoring

### Critical Metrics to Watch

**Every 5 minutes for first hour:**

**Homepage:**
- [ ] Response time < 2s
- [ ] Error rate < 0.1%
- [ ] No 500 errors in Vercel logs

**Safety Suite:**
- [ ] Edge Function healthy
- [ ] Database connections stable
- [ ] No query timeouts

**Log Review:**
```

bash
Supabase
supabase functions logs refresh-safety-summary --tail 50
Vercel (via CLI)
vercel logs truckercore.com --tail 50
GitHub Actions
Check via web UI``` 

**✅ Checkpoint:** All metrics within targets, no critical errors

---

## T+1 Hour: Status Update

### Team Communication

**Post in Slack #engineering:**
```

🚀 TruckerCore v1.2.0 Launch - 1 Hour Update
Status: ✅ GREEN
Deployment: ✅ Database migration complete ✅ Edge Functions deployed & scheduled ✅ Homepage live at https://truckercore.com ✅ All verification tests passing
Metrics (first hour):
Homepage response time: [X]ms avg
Error rate: [X]%
Uptime: 100%
Issues: None / [List any]
Next check: T+4 hours
On-call: @engineer_name``` 

---

## T+4 Hours: Extended Monitoring

### Health Check

- [ ] Run verification: `npm run verify:all`
- [ ] Review logs for anomalies
- [ ] Check performance metrics
- [ ] Review error rates

**If all green:**
- Continue monitoring every 4 hours for first 24h
- Reduce to daily checks after 24h

**If issues found:**
- Assess severity
- Execute rollback if critical
- Document and fix

---

## T+24 Hours: Launch Day Complete

### Final Verification

- [ ] **Run full test suite**
  ```bash
  npm run verify:all
  npm run test:integration
  ```

- [ ] **Performance review**
  - Lighthouse score > 90
  - Core Web Vitals green
  - No performance regressions

- [ ] **Error review**
  - Total errors < 10
  - Zero critical errors
  - All warnings addressed or documented

- [ ] **User feedback**
  - No critical user reports
  - Feature working as expected
  - Mobile experience good

### Success Criteria

**All of the following must be true:**
- [x] Uptime: >99.9%
- [x] Error rate: <0.1%
- [x] Response time: <2s (p95)
- [x] Zero critical bugs
- [x] CRON executed successfully (if occurred)
- [x] All monitoring active

**If all criteria met:** ✅ **LAUNCH SUCCESSFUL**

### Post-Launch Communication

**Post in Slack #engineering:**
```

🎉 TruckerCore v1.2.0 Launch - 24 Hour Success!
Status: ✅ LAUNCH SUCCESSFUL
24h Metrics:
Uptime: [X]%
Avg response time: [X]ms
Total requests: [X]
Error rate: [X]%
Zero critical issues
Next steps:
Continue daily monitoring
Gather user feedback
Plan iteration improvements
Great job team! 🚀``` 

---

## Rollback Procedure

**If critical issues occur, execute immediately:**

### Rollback Steps

**1. Stop CRON (prevents further issues)**
```

bash supabase functions unschedule refresh-safety-summary``` 

**2. Revert Homepage**
```

bash
Option A: Revert via Vercel dashboard
1. Go to https://vercel.com/dashboard
2. Select project → Deployments
3. Find previous deployment
4. Click "..." → "Promote to Production"
Option B: Revert via Git
git revert HEAD git push origin main``` 

**3. Revert Edge Function (if needed)**
```

bash git checkout HEAD~1 -- supabase/functions/refresh-safety-summary/ supabase functions deploy refresh-safety-summary``` 

**4. Revert Migration (CAUTION: May lose data)**
```

bash
Only if absolutely necessary
supabase db reset
Then restore from backup if available``` 

**5. Verify Rollback**
```

bash npm run verify:all``` 

**6. Communicate**
Post in Slack:
```

⚠️ ROLLBACK EXECUTED
Reason: [Brief description]
Components reverted: [List]
Status: [Current state]
Next steps: [Action items]
Incident report to follow.``` 

---

## Post-Launch Tasks (Week 1)

### Daily (First 7 Days)

- [ ] Morning check (09:00)
  - Run `npm run verify:all`
  - Review overnight logs
  - Check error rates

- [ ] Evening check (17:00)
  - Review day's metrics
  - Address any issues
  - Update status

### End of Week 1

- [ ] **Metrics review**
  - Uptime percentage
  - Error trends
  - Performance trends
  - User feedback summary

- [ ] **Documentation update**
  - Document any issues encountered
  - Update troubleshooting guide
  - Add lessons learned

- [ ] **Team retrospective**
  - What went well
  - What could be improved
  - Action items for next release

---

## Success Metrics (30-Day Review)

### Technical Health
- [ ] Uptime: >99.5%
- [ ] Avg response time: <1s
- [ ] Error rate: <0.1%
- [ ] Zero critical bugs

### Business Metrics
- [ ] Homepage visitors: >1,000
- [ ] App sign-ups: >100
- [ ] Feature adoption: >50%
- [ ] User satisfaction: >4.0/5

### Process Metrics
- [ ] Deploy frequency: 2-5/week
- [ ] Deploy success rate: >95%
- [ ] Mean time to recovery: <1h
- [ ] Documentation coverage: 100%

---

## Contact Information

### Launch Day Team

**On-Call Engineer:** _________________  
**Phone:** _________________  
**Slack:** @_________________

**Backup Engineer:** _________________  
**Phone:** _________________  
**Slack:** @_________________

**Engineering Lead:** _________________  
**Phone:** _________________  
**Slack:** @_________________

### Emergency Contacts

**Supabase Support:** support@supabase.com  
**Vercel Support:** support@vercel.com  
**Internal Slack:** #incidents

---

## Notes Section

**Use this space for launch-day notes:**
```

[Timestamp] [Note]
Example:
12:00 - Deployment started
12:15 - Database migration complete
12:20 - Homepage live
12:45 - All tests passing
13:00 - Launch successful``` 

---

**Prepared by:** TruckerCore Engineering Team  
**Last Updated:** 2025-01-XX  
**Version:** 1.0
