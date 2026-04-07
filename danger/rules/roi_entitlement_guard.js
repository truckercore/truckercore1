// Danger rule: Ensure ROI functions enforce exec_analytics entitlement
// If any files under functions/roi* or analytics/roi* are changed, the diff
// must include a reference to get_entitlement(..., 'exec_analytics', ...)

module.exports = async ({ danger, fail, warn }) => {
  const touched = danger.git.fileMatch("functions/roi/**", "analytics/roi/**");
  if (!(touched.edited || touched.created)) return;

  const diff = await danger.git.diff();
  const includesEntitlement = diff.includes("get_entitlement") && diff.includes("exec_analytics");
  if (!includesEntitlement) {
    warn("ROI code changed — expected entitlement check via get_entitlement(..., 'exec_analytics', ...). Add the guard or adjust if handled upstream.");
  }
};
