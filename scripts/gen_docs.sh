#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/Module_Release_Guide.md"
echo "# Module Release Guide" > "$OUT"
for mod in $(ls "$ROOT/module" 2>/dev/null || true); do
  echo -e "\n## ${mod^}\n" >> "$OUT"
  [ -f "$ROOT/module/$mod/README.md" ] && sed -n '1,120p' "$ROOT/module/$mod/README.md" >> "$OUT"
  echo -e "\n**Commands**\n" >> "$OUT"
  echo '```bash' >> "$OUT"
  echo "scripts/run_gate.sh $mod full" >> "$OUT"
  echo "scripts/run_gate.sh $mod probe" >> "$OUT"
  echo '```' >> "$OUT"
done
echo "Docs: $OUT"
