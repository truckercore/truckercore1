// danger/probes.js
const { danger, fail, markdown } = require("danger");
const fs = require("fs");
const path = require("path");

function exists(p) {
  try { fs.accessSync(p); return true; } catch { return false; }
}

async function checkProbeCoverage() {
  // Any module/<name>/ created or changed should include the trio
  const modules = new Set(
    [...danger.git.created_files, ...danger.git.modified_files]
      .map((f) => f.match(/^module\/([^/]+)\//))
      .filter(Boolean)
      .map((m) => m[1])
  );
  if (!modules.size) return;

  const missing = [];
  for (const name of modules) {
    const base = path.join("module", name);
    const need = ["smoke.sh", "gate_sql.sh", "probe.sh"].map((x) => path.join(base, x));
    const absent = need.filter((p) => !exists(p));
    if (absent.length) missing.push({ name, absent });
  }

  if (missing.length) {
    fail(
      "Probe coverage check failed:\n" +
        missing
          .map((m) => `- module/${m.name} missing: ${m.absent.map((a) => path.basename(a)).join(", ")}`)
          .join("\n")
    );
  } else {
    markdown("✅ Probe coverage present (smoke/gate_sql/probe).");
  }
}

module.exports = { checkProbeCoverage };
