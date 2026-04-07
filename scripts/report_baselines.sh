#!/usr/bin/env bash
set -euo pipefail
CSV="${REPORT_DIR:-./reports}/probes.csv"; OUT="${REPORT_DIR:-./reports}/index.html"
echo "<html><body><h3>Probe Baselines</h3><table border=1><tr><th>module</th><th>name</th><th>samples</th><th>p50</th><th>p95</th><th>ts</th></tr>" > "$OUT"
tail -n +2 "$CSV" | awk -F, '{printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",$1,$2,$3,$4,$5,$6}' >> "$OUT"
echo "</table></body></html>" >> "$OUT"
echo "📊 Wrote $OUT"
