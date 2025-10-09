module.exports = async ({ danger, warn }) => {
  const changed = danger.git.fileMatch(
    "functions/**/promote_model_v2/**",
    "module/promoctl/**"
  );
  if (changed.edited || changed.created) {
    warn("Promotion control-plane changed — update module/promoctl/* gates and runbook canary steps.");
  }
};
