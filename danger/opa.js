// danger/opa.js
const { danger, fail, markdown } = require("danger");
const fs = require("fs");
const path = require("path");

function pathExists(p) {
  try {
    fs.accessSync(p);
    return true;
  } catch {
    return false;
  }
}

async function checkOpaPolicies() {
  const newModules = new Set(
    danger.git.created_files
      .map((f) => f.match(/^modules\/([^/]+)\//) || f.match(/^module\/([^/]+)\//))
      .filter(Boolean)
      .map((m) => m[1])
  );

  if (!newModules.size) return;

  const missing = [];
  for (const m of newModules) {
    const rego1 = path.join("policy", "opa", `${m}.rego`);
    const rego2 = path.join("policies", "opa", `${m}.rego`);
    if (!pathExists(rego1) && !pathExists(rego2)) {
      missing.push(m);
    }
  }

  if (missing.length) {
    fail(
      `OPA policies required for new modules: ${missing
        .map((m) => `\`${m}\``)
        .join(", ") } (expected policy/opa/<module>.rego).`
    );
  } else {
    markdown("✅ OPA policy detected for new modules.");
  }
}

module.exports = { checkOpaPolicies };
