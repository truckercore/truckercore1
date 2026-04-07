#!/usr/bin/env bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "==> Parking + Promos + POIs chaos"
bash "$ROOT/module/parking/smoke.sh"
bash "$ROOT/module/promos/smoke.sh"
bash "$ROOT/module/pois/smoke.sh"
bash "$ROOT/module/parking/probe.sh" || true
bash "$ROOT/module/promos/probe.sh"  || true
bash "$ROOT/module/pois/probe.sh"    || true
echo "✅ Chaos drill done (lenient probes)"
