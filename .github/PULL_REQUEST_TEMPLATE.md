## Summary

- [ ] Purpose of this change (bug fix, feature, refactor, security hardening)
- [ ] Linked issue(s):

## Security Checklist

- [ ] Threat model updated or reviewed for this change (see THREAT_MODEL.md)
- [ ] Org scoping/authorization verified for all new/changed endpoints (ensureOrgScope / RLS)
- [ ] No service-role credentials used on user endpoints (see api/lib/service_guard.ts)
- [ ] Webhook verification (signature, timestamp skew, replay, idempotency) enforced where applicable
- [ ] Secrets not logged; logs use structured redaction (api/lib/logging.ts)
- [ ] Data minimization: only required fields collected; retention documented/unchanged
- [ ] Tests updated/added for authZ/authN paths and redaction
- [ ] Dependency changes reviewed; SCA/SAST passes (build must be green)

## Risk & Rollout

- [ ] Backward compatible
- [ ] Rollout plan and monitoring (dashboards/alerts) ready
- [ ] Runbook updated if needed

## Screenshots/Notes

