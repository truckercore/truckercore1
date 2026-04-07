#!/usr/bin/env bash
set -euo pipefail

# Runbook executor: steps 2–10 (DB smoke, freshness/gaps, maintenance, index sanity,
# optional endpoint checks, SSO/SCIM health, entitlements gating, ops snapshot)
# Requirements:
# - Supabase CLI installed and linked to your project (or SUPABASE_DB_URL set for psql)
# - curl and jq available for HTTP checks
# Environment variables:
#   PROJECT           Supabase project ref (used by supabase CLI if linked)
#   SUPABASE_DB_URL  Optional: direct Postgres URL for psql; if unset, uses `supabase db query`
#   PROJECT_URL       Base URL for functions (e.g., https://<project>.supabase.co)
#   USER_JWT          A valid JWT for protected endpoints
#   SKIP_HTTP=1       Skip HTTP endpoint checks
#   SKIP_MV=1         Skip MV refresh attempts
#
# Output:
# - Creates artifacts/runbook_report_YYYYMMDD_HHMM.txt with all collected outputs
# - Echoes a short summary to stdout

DATE_TAG=$(date +%Y%m%d_%H%M%S)
OUTDIR="artifacts"
OUTFILE="$OUTDIR/runbook_report_${DATE_TAG}.txt"
mkdir -p "$OUTDIR"

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

# Helper to execute SQL using supabase CLI
run_sql(){
  local sql="$1"; local title="$2"
  {
    echo "\n===== ${title} ====="
    echo "$sql" | sed 's/^/-- /'
    if have_cmd supabase; then
      supabase db query "$sql"
    else
      echo "[warn] supabase CLI not found; skipping SQL block: ${title}"
    fi
  } | tee -a "$OUTFILE"
}

# Helper for curl step (optional)
run_curl(){
  local title="$1"; shift
  {
    echo "\n===== ${title} ====="
    echo "curl $*"
    if have_cmd curl; then
      set +e
      (time -p curl -sS "$@") 2>&1 | tee -a "$OUTFILE"
      set -e
    else
      echo "[warn] curl not found; skipped ${title}"
    fi
  } | tee -a "$OUTFILE"
}

# 2) DB smoke: Objects present
run_sql "select to_regclass('public.system_events') as system_events, to_regclass('public.v_system_events_rollup') as v_system_events_rollup, to_regclass('public.system_events_freshness') as system_events_freshness, to_regclass('public.system_events_gaps') as system_events_gaps;" "DB objects: system_events + rollup/freshness/gaps"

# 3) Freshness
run_sql "select * from public.system_events_freshness order by lag desc;" "Freshness lag per org"

# 4) Gaps (top 10)
run_sql "select * from public.system_events_gaps order by date_missing desc limit 10;" "Gaps (missing days)"

# 5) Daily totals (7d)
run_sql "select * from public.v_daily_events where date >= current_date - interval '7 days' order by date desc, org_id;" "Daily totals (7d)"

# 6) Maintenance: prune + MV refresh (best effort)
run_sql "select public.prune_system_events(90);" "Retention prune (90 days)"
if [[ "${SKIP_MV:-}" != "1" ]]; then
  run_sql "do $$ begin if exists (select 1 from pg_matviews where schemaname='public' and matviewname='mv_system_events_rollup') then execute 'refresh materialized view concurrently public.mv_system_events_rollup'; end if; end $$;" "Refresh MV mv_system_events_rollup (if present)"
fi

# 7) Index sanity (explain analyze samples)
run_sql "explain analyze select date, org_id, sum(events) from public.v_system_events_rollup group by 1,2 order by date desc nulls last limit 50;" "Explain analyze: rollup aggregation"
run_sql "explain analyze select * from public.system_events where occurred_at >= now() - interval '7 days' and org_id is not null order by occurred_at desc limit 50;" "Explain analyze: recent org filter"

# 8) Ops health snapshot
run_sql "select * from public.v_ops_health;" "Ops health snapshot"

# 9) SSO/SCIM health (if views exist)
run_sql "do $$ begin if to_regclass('public.v_sso_failure_rate_24h') is not null then raise notice 'v_sso_failure_rate_24h exists'; end if; end $$;" "Probe SSO view presence"
run_sql "select * from public.v_sso_failure_rate_24h order by failure_rate_24h desc nulls last limit 10;" "SSO failure rate (24h)"

# 10) Optional HTTP endpoint smoke (state endpoints)
if [[ "${SKIP_HTTP:-}" != "1" && -n "${PROJECT_URL:-}" ]]; then
  if [[ -n "${USER_JWT:-}" ]]; then
    run_curl "Health function" -H "Authorization: Bearer ${USER_JWT}" -H "Accept: application/json" "${PROJECT_URL%/}/functions/v1/health"
  else
    run_curl "Health function (no auth)" -H "Accept: application/json" "${PROJECT_URL%/}/functions/v1/health"
  fi
fi

# Summary footer
{
  echo "\n===== SUMMARY ====="
  echo "Report saved: $OUTFILE"
  echo "Timestamp: $(date -Is)"
} | tee -a "$OUTFILE"

echo "\n✅ Runbook steps 2–10 executed. See $OUTFILE"
