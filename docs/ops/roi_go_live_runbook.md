# ROI Go-Live Validation Runbook

This runbook is copy/paste friendly for cold-start validation, guardrails, and governance checks.

Prereqs:
- ENV set: SUPABASE_URL, SUPABASE_DB_URL, SUPABASE_SERVICE_ROLE_KEY, FUNC_URL
- Deno functions deployed (roi/*, reports_exec_roi)

## 1) Cold start → report

- Refresh rollups and export JSON/HTML for a known org

```bash
curl -fsS "$FUNC_URL/roi/export_rollup?org_id=$ORG"
curl -fsS "$FUNC_URL/roi/export_html?org_id=$ORG"
```

Validate:
- last_refresh_at < 24h from export_rollup response
- exec_analytics entitlement OFF → both endpoints return 403

## 2) Executive PDF (signed)

Generate and verify checksum matches evidence log:

```bash
resp=$(curl -fsS -X POST "$FUNC_URL/reports_exec_roi" -H 'content-type: application/json' -d '{"org_id":"'$ORG'","range_days":30,"format":"pdf"}')
url=$(echo "$resp" | jq -r .url)
hash=$(echo "$resp" | jq -r .hash_sha256)

# Fetch file and verify
curl -fsS "$url" -o /tmp/exec_roi.pdf
calc=$(sha256sum /tmp/exec_roi.pdf | awk '{print $1}')
[ "$calc" = "$hash" ] && echo "✅ checksum match" || echo "❌ checksum mismatch"
```

## 3) Backfill safety (dry-run)

- Run backfill for a small org/date in DRYRUN:

```bash
psql "$SUPABASE_DB_URL" -c "select fn_roi_backfill('$ORG'::uuid, 7, 'default', true);"
```

- Ensure is_backfill=true rows are excluded from live KPIs (ai_roi_rollup_day already excludes backfills).

## 4) Guardrails & Alerts

- Rollup stale >24h: `select * from v_alert_rollup_stale_24h;`
- Anomaly spike >3× 7d median: `select * from v_ai_roi_spike_alerts;`
- Explainability rate <98% (24h): `select * from v_alert_explainability_missing;`
- Export latency budget p95>2s (1h): `select * from v_alert_roi_export_latency;`
- Cost guard (event outliers): `select * from v_alert_roi_event_outliers;`

## 5) Governance

Danger rule:
- ROI code changes must include probes and runbook delta.

OPA:
- Block when exec_analytics=true but no effective baselines.

## 6) Rotate report signing keys (quarterly)

- Rotate the key in your storage/signing service.
- Record evidence:

```sql
insert into compliance_evidence(org_id, artifact, source)
values (null, 'report_signing_keys_rotated:'||now()::text, 'key_rotation');
```

## 7) Rebuild baseline snapshots (fuel volatility or policy change)

- Insert a new snapshot in `ai_roi_baseline_defaults` and/or `ai_roi_baselines` (never overwrite).
- Run a scoped backfill (optional):

```sql
select fn_roi_backfill('$ORG'::uuid, 14, 'policy_change', true); -- dry-run
-- then run with false to apply
```

- Re-run executive report; tag “recomputed” in evidence:

```sql
insert into compliance_evidence(org_id, artifact, source)
values ('$ORG'::uuid, 'exec_roi_recomputed_'||now()::date, 'report_recompute');
```

## 8) SSO Canary Widgets

- Keep cert-expiry and group-drift visible on exec dashboard (views: iam_saml_expiring, iam_group_drift).

## 9) Data Retention

- Purge ROI raw events older than 18 months (dry-run first):

```sql
select fn_roi_retention_purge(true); -- review
select fn_roi_retention_purge(false); -- apply
```

## 10) Demo Script (exec-friendly)

- Open dashboard → show 30‑day ROI total & breakdown.
- Click “Download Executive Report” → show signed PDF link + checksum.
- Toggle exec_analytics OFF → export returns 403.
- Re-enable → rerun export; show last_refresh_at and anomaly section.
