// Require probe artifacts and OPA eval outputs when probes or policies change
module.exports = async ({ danger, fail, warn }) => {
  const files = danger.git.modified_files.concat(danger.git.created_files);
  const probesChanged = files.some(f => /^module\/.+\/(probe\.sh|smoke\.sh)$/.test(f));
  const opaChanged = files.some(f => f.startsWith("policies/") || f.includes("opa"));

  if (probesChanged) {
    const hasCsv = files.includes("reports/probes.csv");
    const hasIndex = files.includes("reports/index.html");
    if (!hasCsv || !hasIndex) fail("Probe artifacts missing: require reports/probes.csv and reports/index.html");
  }

  if (opaChanged) {
    const hasEval = files.includes("reports/policy_eval.json");
    if (!hasEval) fail("OPA evaluation missing: require reports/policy_eval.json");
  }

  // New module requires matching runbook
  const newModules = files
    .filter(f => /^module\/([^/]+)\/$/.test(f) || /^module\/[^/]+\/.*$/.test(f))
    .map(f => f.split("/")[1]);
  const unique = Array.from(new Set(newModules));
  for (const m of unique) {
    const hasRunbook = files.some(f => f === `docs/runbooks/${m}.md` || f.startsWith(`docs/runbooks/${m}/`));
    if (!hasRunbook) fail(`Missing runbook documentation for module '${m}' in docs/runbooks/${m}`);
  }

  // Test presence for new functions
  const newFns = files.filter(f => f.startsWith("functions/"));
  if (newFns.length) {
    const hasTests = files.some(f => /\.test\.ts$|\.spec\.ts$/.test(f));
    if (!hasTests) fail("Added functions require at least one new *.test.ts or *.spec.ts");
  }
};
