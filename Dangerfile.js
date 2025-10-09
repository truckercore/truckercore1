// Dangerfile.js – modular checks wired via /danger helpers
const { danger, markdown } = require('danger');
const { checkRunbooks } = require('./danger/runbooks.js');
const { checkIdempotency } = require('./danger/idempotency.js');
const { checkOpaPolicies } = require('./danger/opa.js');
const { checkProbeCoverage } = require('./danger/probes.js');
const { checkPrLabels } = require('./danger/labels.js');
// Endpoint registry guard (schedules itself on require)
require('./danger/rules/endpoints.js');
// Promoctl guard
require('./danger/rules/promoctl.js');
// Promoctl required gates guard
require('./danger/rules/promoctl_required_gates.js');

function hasBypassAll() {
  const pr = danger.github?.pr || {};
  const labels = (pr.labels || []).map((l) => l.name);
  return labels.some((l) => /^bypass:all$/i.test(l));
}

schedule(async () => {
  const bypassAll = hasBypassAll();
  if (!bypassAll) {
    await checkRunbooks();
    await checkIdempotency();
    await checkOpaPolicies();
    await checkProbeCoverage();
    await checkPrLabels();
  } else {
    markdown('⛳ Bypass:all present — Danger checks skipped (ensure CODEOWNERS approval).');
  }
});
