// danger/labels.js
const { danger, fail, warn, markdown } = require("danger");

async function checkPrLabels() {
  const pr = danger.github?.pr;
  if (!pr) return;

  const labels = (pr.labels || []).map((l) => l.name);
  const hasType = labels.some((l) => /^type:(feature|fix|ops)$/i.test(l));
  if (!hasType) fail("PR must include a label: type:feature | type:fix | type:ops");

  // Security review requirement when touching sensitive areas
  const sensitive = danger.git.fileMatch(
    'api/lib/webhook.*',
    'api/**/webhook*.*',
    'api/lib/guard.*',
    'api/lib/service_guard.*',
    'policies/**',
    'policy/**',
    'db/**',
    'supabase/**',
    'security/**',
    'ci/**',
    '.github/workflows/**'
  );
  const touchedSensitive = sensitive.edited || sensitive.created || sensitive.modified;
  const hasSecLabel = labels.some((l) => /^security-review$/i.test(l));
  if (touchedSensitive && !hasSecLabel) {
    fail("Changes touch auth/crypto/webhooks/RLS/CI — add label: security-review and obtain security approval.");
  }

  // Optional: skip-changelog hint
  const hasSkip = labels.includes("skip-changelog");
  // if (!hasSkip) {
  //   warn("Consider adding 'skip-changelog' if this PR doesn't affect user-facing changes.");
  // }

  markdown(`🧾 Labels: ${labels.join(", ") || "(none)"}`);
}

module.exports = { checkPrLabels };
