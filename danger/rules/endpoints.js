const changedProbes = danger.git.fileMatch("module/**/smoke.sh", "module/**/probe.sh");
const changedFns = danger.git.fileMatch("functions/**/index.ts");
const registryChanged = danger.git.fileMatch("scripts/ai_endpoints.json");

schedule(async () => {
  if ((changedProbes.edited || changedFns.edited) && !registryChanged.edited) {
    warn("AI endpoints changed but scripts/ai_endpoints.json did not. Consider updating the registry so CI stays aligned.");
  }
});
