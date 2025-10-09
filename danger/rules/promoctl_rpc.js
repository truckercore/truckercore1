// danger/rules/promoctl_rpc.js
module.exports = async ({ danger, warn }) => {
  const changed = danger.git.fileMatch(
    "functions/**/promote_model_v2/**",
    "db/migrations/**/ai_promote_tx*.sql"
  );
  if (changed.edited || changed.created) {
    warn("Promotion plane changed. Ensure callers ONLY invoke `ai_promote_tx` and run `gate_promo_sql` + concurrency probe.");
  }
};
