#!/usr/bin/env bash
set -euo pipefail

# scripts/runbook.sh
# Wrapper for executing the runbook with deterministic header, redaction, trimming,
# monotonic duration, config merge, and sidecar JSON emission.
# It reuses scripts/runbooks/execute_runbook.sh for the actual steps (2–10).
# Env in: PROJECT_URL, SKIP_HTTP, SKIP_MV, ALLOW_PARTIAL, SIDECAR (optional path for JSON)

# --- Helpers ---
NOW_UTC_ISO() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
LOCAL_TZ_NAME() {
  # Best-effort local timezone name
  if [ -f /etc/timezone ]; then cat /etc/timezone; 
  elif command -v timedatectl >/dev/null 2>&1; then timedatectl 2>/dev/null | awk -F': ' '/Time zone/ {print $2}' | awk '{print $1}';
  else printf "%s" "$(date +%Z)"; fi
}
UTC_HEADER_TIME() { date -u +"%H:%M:%S"; }
LOCAL_HEADER_TIME() { date +"%Y-%m-%d %H:%M:%S"; }
GIT_SHA() { git rev-parse --verify HEAD 2>/dev/null || echo "unknown"; }

# Monotonic clock via Node (perf_hooks) for portability
MONO_NOW_MS() { node -e "const {performance}=require('perf_hooks'); console.log(Math.round(performance.now()))" 2>/dev/null || echo 0; }

# Redact tokens/secrets/keys/jwt/password values in a stream
redact_stream() {
  # Replace key=value and JSON fields with **** for sensitive keys
  sed -E \
    -e 's/((?i)(token|secret|password|jwt|key))=([^[:space:]]+)/\1=****/g' \
    -e 's/(["\'\'](?i)(token|secret|password|jwt|key)["\'\']\s*:\s*["\'\'][^"\'\']*["\'\'])/"\2":"****"/g'
}

# Trim to last N lines; prefix if truncated
trim_tail() {
  local n=${1:-300}
  local tmp
  tmp=$(mktemp)
  cat >"$tmp"
  local lines total
  total=$(wc -l <"$tmp" | tr -d ' ')
  if [ "$total" -gt "$n" ]; then
    echo "(truncated…)"
    tail -n "$n" "$tmp"
  else
    cat "$tmp"
  fi
  rm -f "$tmp"
}

# Config loader (runbook.config.json or .runbookrc) -> environment merge
load_config() {
  local cfg_file=""
  if [ -f runbook.config.json ]; then cfg_file=runbook.config.json; fi
  if [ -z "$cfg_file" ] && [ -f .runbookrc ]; then cfg_file=.runbookrc; fi
  if [ -n "$cfg_file" ] && command -v jq >/dev/null 2>&1; then
    export SKIP_HTTP=${SKIP_HTTP:-$(jq -r '(.skip_http // .SKIP_HTTP // env.SKIP_HTTP // "0")' "$cfg_file")}
    export SKIP_MV=${SKIP_MV:-$(jq -r '(.skip_mv // .SKIP_MV // env.SKIP_MV // "0")' "$cfg_file")}
    export ALLOW_PARTIAL=${ALLOW_PARTIAL:-$(jq -r '(.allow_partial // .ALLOW_PARTIAL // env.ALLOW_PARTIAL // "0")' "$cfg_file")}
  fi
}

# --- Begin ---
load_config

local_tz=$(LOCAL_TZ_NAME)
local_time=$(LOCAL_HEADER_TIME)
utc_time=$(UTC_HEADER_TIME)
header_ts="${local_time} ${local_tz} (UTC ${utc_time})"
sha=$(GIT_SHA)
report_version="1.0"
project_url=${PROJECT_URL:-}
flags_json=$(jq -nc --arg skip_http "${SKIP_HTTP:-0}" --arg skip_mv "${SKIP_MV:-0}" --arg allow_partial "${ALLOW_PARTIAL:-0}" '{SKIP_HTTP:$skip_http, SKIP_MV:$skip_mv, ALLOW_PARTIAL:$allow_partial}')

start_ms=$(MONO_NOW_MS)
start_utc=$(NOW_UTC_ISO)

# Print header (do not dump full env)
echo "Runbook Report"
echo "Timestamp: ${header_ts}"
echo "Git SHA: ${sha}"
echo "Project URL: ${project_url}"
echo "Flags: SKIP_HTTP=${SKIP_HTTP:-0} SKIP_MV=${SKIP_MV:-0} ALLOW_PARTIAL=${ALLOW_PARTIAL:-0}"
echo "----------------------------------------"

# Execute the main runbook and capture output
# We'll redact and trim after capture
work_tmp=$(mktemp)
set +e
scripts/runbooks/execute_runbook.sh >"$work_tmp" 2>&1
code=$?
set -e

# Redact and trim
redacted_tmp=$(mktemp)
cat "$work_tmp" | redact_stream > "$redacted_tmp"
# emit body with trimming to keep report readable
cat "$redacted_tmp" | trim_tail 300

end_ms=$(MONO_NOW_MS)
duration_ms=$(( end_ms - start_ms ))
if [ "$duration_ms" -lt 0 ]; then duration_ms=0; fi

ok_count=0; fail_count=0
# Heuristic: count FAIL markers if present; else use exit code
if grep -q "Status: FAIL" "$redacted_tmp"; then
  fail_count=$(grep -c "Status: FAIL" "$redacted_tmp" || true)
fi
if grep -q "Status: OK" "$redacted_tmp"; then
  ok_count=$(grep -c "Status: OK" "$redacted_tmp" || true)
fi

# Exit policy
exit_code=$code
if [ "$fail_count" -gt 0 ] && [ "${ALLOW_PARTIAL:-0}" != "1" ]; then
  exit_code=1
fi

# Sidecar JSON
sidecar_path=${SIDECAR:-}
if [ -n "$sidecar_path" ]; then
  mkdir -p "$(dirname "$sidecar_path")"
  jq -nc \
    --arg report_version "$report_version" \
    --arg generated_at "$start_utc" \
    --arg timezone "$local_tz" \
    --arg git_sha "$sha" \
    --arg project_url "$project_url" \
    --argjson flags "$flags_json" \
    --arg filename_txt "" \
    --arg filename_json "" \
    --argjson summary "$(jq -nc --argjson ok "$ok_count" --argjson fail "$fail_count" --argjson duration_ms "$duration_ms" --argjson exit_code "$exit_code" '{ok: $ok, fail: $fail, duration_ms: $duration_ms, exit_code: $exit_code}')" \
    '{report_version: $report_version, generated_at: $generated_at, timezone: $timezone, git_sha: $git_sha, project_url: $project_url, flags: $flags, filename_txt: $filename_txt, filename_json: $filename_json, summary: $summary}' \
    > "$sidecar_path"
  # Basic sanity: ensure no secrets leaked
  if grep -Eiq 'token|secret|password|jwt|key' "$sidecar_path"; then
    # Redact entire file if suspicious
    tmp_sc=$(mktemp); cat "$sidecar_path" | redact_stream > "$tmp_sc" && mv "$tmp_sc" "$sidecar_path"
  fi
fi

# Footer
echo "----------------------------------------"
echo "Duration (ms): ${duration_ms}"
echo "Exit code: ${exit_code}"

exit "$exit_code"
