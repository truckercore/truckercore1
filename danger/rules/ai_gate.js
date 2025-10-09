module.exports = async ({ danger, fail, warn }) => {
  const aiTouched = danger.git.fileMatch(
    "functions/**/ai_*/**",
    "functions/**/ai_ct/**",
    "module/ai-*/**",
    "scripts/ai_endpoints.json"
  );
  const needsGate = aiTouched.edited || aiTouched.created;

  if (needsGate) {
    const workflowHint = "Ensure the `AI Gate` workflow ran and passed (registry_check, smokes, probes, health).";
    warn(`AI components changed. ${workflowHint}`);
  }
};
