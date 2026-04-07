module.exports = async ({ danger, warn, fail }) => {
  const ctrl = danger.git.fileMatch(
    "functions/**/promote_model_v2/**",
    "db/migrations/ai_rollouts/040_promote_tx.sql"
  );
  if (ctrl.edited || ctrl.created) {
    const smoke = danger.git.fileMatch("module/promoctl/smoke.sh");
    const probe = danger.git.fileMatch("module/promoctl/probe.sh");
    const conc  = danger.git.fileMatch("module/promoctl/concurrency_probe.sh");
    const missing = [];
    if (!(smoke.created || smoke.edited)) missing.push("smoke.sh");
    if (!(probe.created || probe.edited)) missing.push("probe.sh");
    if (!(conc.created || conc.edited))   missing.push("concurrency_probe.sh");
    if (missing.length) {
      fail(`promoctl changed — update module/promoctl gates: ${missing.join(', ')} or justify with bypass label.`);
    }
  }
};