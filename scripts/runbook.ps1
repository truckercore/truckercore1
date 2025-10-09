# scripts/runbook.ps1
# PowerShell version of the runbook executor (Steps 2–10)
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\runbook.ps1

param()

$PROJECT_URL = $env:PROJECT_URL
if (-not $PROJECT_URL) { $PROJECT_URL = 'http://127.0.0.1:54321' }
$SKIP_HTTP = if ($env:SKIP_HTTP) { [int]$env:SKIP_HTTP } else { 0 }
$SKIP_MV   = if ($env:SKIP_MV)   { [int]$env:SKIP_MV }   else { 0 }
$ALLOW_PARTIAL = if ($env:ALLOW_PARTIAL) { [int]$env:ALLOW_PARTIAL } else { 0 }

# Warn for Android emulator hint
if ($PROJECT_URL -match '^http://(localhost|127\.0\.0\.1)') {
  Write-Warning 'PROJECT_URL points to localhost; for Android emulator use http://10.0.2.2:54321'
}

$TS = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$TZ_NAME = [System.TimeZoneInfo]::Local.Id
try { $SHA = (git rev-parse --short HEAD) } catch { $SHA = 'unknown' }
$REPORT_TS = Get-Date -Format 'yyyyMMdd_HHmm'

$global:STEP = 2
$global:OK = 0
$global:FAIL = 0
$start = Get-Date

function Trim-Output([string]$s, [int]$n = 200) {
  $lines = $s -split "`n"
  if ($lines.Count -gt $n) { ($lines | Select-Object -Last $n) -join "`n" } else { $s }
}

function Mask-Secret([string]$s) {
  $jwt = $env:USER_JWT
  if ($null -ne $jwt -and $jwt -ne '') { return $s -replace [Regex]::Escape($jwt), '****…****' }
  return $s
}

function Run-Step([string]$name, [string]$cmd) {
  Write-Host "`n===== STEP $global:STEP: $name ====="
  Write-Host "CMD: $cmd"
  $t0 = Get-Date
  $ps = Start-Process -FilePath 'powershell' -ArgumentList "-NoProfile","-Command", $cmd -NoNewWindow -RedirectStandardOutput temp_stdout.txt -RedirectStandardError temp_stderr.txt -PassThru
  $ps.WaitForExit()
  $code = $ps.ExitCode
  $out = ''
  if (Test-Path temp_stdout.txt) { $out += Get-Content temp_stdout.txt -Raw }
  if (Test-Path temp_stderr.txt) { $out += "`n" + (Get-Content temp_stderr.txt -Raw) }
  Remove-Item -ErrorAction SilentlyContinue temp_stdout.txt, temp_stderr.txt
  Write-Host "--- OUTPUT (trimmed) ---"
  Write-Host (Mask-Secret (Trim-Output $out 200))
  if ($code -eq 0) { $global:OK++ ; Write-Host 'Status: OK' } else { $global:FAIL++ ; Write-Host 'Status: FAIL' }
  switch ($name) {
    'DB Objects present'          { if ($code -ne 0) { Write-Host 'Hint: If FAIL_DB_OBJECTS → run: supabase db push' } }
    'Freshness <= 60m'            { if ($code -ne 0) { Write-Host 'Hint: If FAIL_FRESHNESS → verify ingestion jobs and recent events in system_events' } }
    'No gaps (14–30d window)'     { if ($code -ne 0) { Write-Host 'Hint: If FAIL_GAPS → backfill or validate scheduler producing system_events daily' } }
    'Daily totals present (7d)'   { if ($code -ne 0) { Write-Host 'Hint: If FAIL_DAILY → refresh mv or check v_daily_events definition' } }
    'Retention + MV maintenance'  { if ($code -ne 0) { Write-Host 'Hint: If FAIL_MAINT → ensure function grants and run: select public.prune_system_events(90);' } }
    'Index sanity (EXPLAIN)'      { if ($code -ne 0) { Write-Host 'Hint: If FAIL_EXPLAIN → ensure idx_system_events_org_time / idx_system_events_code_time exist' } }
    'HTTP health endpoints'       { if ($code -ne 0) { Write-Host 'Hint: If FAIL_HTTP → start local Supabase with: supabase start (and supabase functions serve)' } }
    'Ops health snapshot'         { if ($code -ne 0) { Write-Host 'Hint: If FAIL_OPS_HEALTH → inspect view v_ops_health and base tables'' RLS' } }
  }
  $global:STEP++
}

Write-Host "Runbook Report"
Write-Host "Timestamp: $TS ($TZ_NAME)"
Write-Host "Git SHA: $SHA"
Write-Host "PROJECT_URL: $PROJECT_URL"
Write-Host "Flags: SKIP_HTTP=$SKIP_HTTP SKIP_MV=$SKIP_MV ALLOW_PARTIAL=$ALLOW_PARTIAL"

# STEP 2
Run-Step 'DB Objects present' "supabase db query \"select to_regclass('public.system_events'), to_regclass('public.v_system_events_rollup'), to_regclass('public.system_events_freshness'), to_regclass('public.system_events_gaps');\""
# STEP 3
Run-Step 'Freshness <= 60m' "powershell -NoProfile -Command \"$r = supabase db query 'select max(lag) as worst_lag from public.system_events_freshness;'; echo $r; $ok = supabase db query 'select (max(lag) <= interval ''60 minutes'') as ok from public.system_events_freshness;'; if ($ok -match ' t') { exit 0 } else { exit 1 }\""
# STEP 4
Run-Step 'No gaps (14–30d window)' "powershell -NoProfile -Command \"$x = supabase db query 'select count(*) as gaps from public.system_events_gaps;'; if ($x -match ' 0$') { exit 0 } else { echo $x; exit 1 }\""
# STEP 5
Run-Step 'Daily totals present (7d)' "supabase db query \"select * from public.v_daily_events where date >= current_date - interval '7 days' order by date desc, org_id;\""
# STEP 6
if ($SKIP_MV -eq 1) {
  Write-Host "===== STEP $global:STEP: Retention + MV maintenance (skipped) ====="
  $global:STEP++
} else {
  Run-Step 'Retention + MV maintenance' "powershell -NoProfile -Command \"supabase db query 'select public.prune_system_events(90);'; supabase db query 'do $$ begin if exists (select 1 from pg_matviews where schemaname=''public'' and matviewname=''mv_system_events_rollup'') then refresh materialized view concurrently public.mv_system_events_rollup; end if; end $$;';\""
}
# STEP 7
Run-Step 'Index sanity (EXPLAIN)' "supabase db query \"explain analyze select * from public.system_events where org_id is not null order by occurred_at desc limit 50;\""
# STEP 8
if ($SKIP_HTTP -eq 1) {
  Write-Host "===== STEP $global:STEP: HTTP health endpoints (skipped) ====="
  $global:STEP++
} else {
  Run-Step 'HTTP health endpoints' "powershell -NoProfile -Command \"Invoke-WebRequest -UseBasicParsing -Uri '$PROJECT_URL/functions/v1/health' | Out-String; Invoke-WebRequest -UseBasicParsing -Uri '$PROJECT_URL/rest/v1/health' | Out-String\""
}
# STEP 9
Run-Step 'Ops health snapshot' "supabase db query \"select * from public.v_ops_health limit 1;\""
# STEP 10
Run-Step 'Hazards/incidents sample' "powershell -NoProfile -Command \"$r = supabase db query 'select 1 from to_regclass(''public.v_hazards_recent'');'; if ($LASTEXITCODE -eq 0) { supabase db query 'select count(*) from public.v_hazards_recent where observed_at >= now()-interval ''48 hours'';'; exit $LASTEXITCODE } else { supabase db query 'select count(*) from to_regclass(''public.v_incidents_overlay'');'; }\""

# Summary
$dur = [int]((Get-Date) - $start).TotalSeconds
Write-Host "`n===== SUMMARY ====="
Write-Host "ok=$global:OK fail=$global:FAIL duration_s=$dur"
$exitCode = 0
if ($global:FAIL -gt 0 -and $ALLOW_PARTIAL -ne 1) { $exitCode = 1 }
Write-Host "Exit code (planned): $exitCode"
exit $exitCode
