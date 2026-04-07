module.exports = async ({ danger, warn }) => {
  const changed = danger.git.fileMatch(
    "functions/**/scim-*/**",
    "functions/**/saml-*/**",
    "db/migrations/identity/**",
    "module/identity/**"
  );
  if (changed.edited || changed.created) {
    warn("Identity (SAML/SCIM) components changed. Ensure identity module gates and runbook are updated and CI gates ran.");
  }
};