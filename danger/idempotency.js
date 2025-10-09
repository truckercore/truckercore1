// danger/idempotency.js
const { danger, fail, markdown } = require("danger");
const fs = require("fs");

const MUTATING = ["POST", "PUT", "PATCH", "DELETE"];

function fileText(p) {
  try {
    return fs.readFileSync(p, "utf8");
  } catch {
    return "";
  }
}

// Heuristics: in functions/**/index.ts detect route handlers and require ensureIdempotent or withIdempotency
async function checkIdempotency() {
  const changed = [...danger.git.created_files, ...danger.git.modified_files].filter((f) => /^functions\/.+\/index\.ts$/i.test(f));
  if (!changed.length) return;

  const offenders = [];
  for (const f of changed) {
    const txt = fileText(f);
    const hasMutatingRoute = /router\.(post|put|patch|delete)\(/i.test(txt) ||
      /\bapp\.(post|put|patch|delete)\(/i.test(txt) ||
      (/\bDeno\.serve\(/.test(txt) && /\b(req\.method)\b/.test(txt) && /(POST|PUT|PATCH|DELETE)/.test(txt));

    if (!hasMutatingRoute) continue;

    const hasGuard = /\bensureIdempotent\b/.test(txt) || /\bwithIdempotency\b/.test(txt) || /\bIdempotency-Key\b/i.test(txt);

    if (!hasGuard) offenders.push(f);
  }

  if (offenders.length) {
    fail(
      `Idempotency enforcement missing in:\n${offenders.map((x) => `- ${x}`).join("\n")}\nRequire ensureIdempotent/withIdempotency on mutating endpoints.`
    );
  } else {
    markdown("✅ Idempotency checks present for mutating handlers.");
  }
}

module.exports = { checkIdempotency };
