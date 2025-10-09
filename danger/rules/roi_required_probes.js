// Danger rule to ensure probes accompany ROI changes
module.exports = async ({ danger, warn }) => {
  const roiTouched = danger.git.fileMatch("functions/roi/**", "db/migrations/roi/**");
  if (roiTouched.edited || roiTouched.created) {
    const smoke = danger.git.fileMatch("module/roi/smoke_log_and_rollup.sh");
    const gate = danger.git.fileMatch("scripts/gate_roi_sql.sh");
    const probe = danger.git.fileMatch("module/roi/probe_rationale_required.sh");
    const runbook = danger.git.fileMatch("docs/ops/roi_go_live_runbook.md");
    if (!smoke.edited && !smoke.created) warn("ROI changed — add/update module/roi/smoke_log_and_rollup.sh");
    if (!gate.edited && !gate.created) warn("ROI changed — add/update scripts/gate_roi_sql.sh");
    if (!probe.edited && !probe.created) warn("ROI changed — add/update module/roi/probe_rationale_required.sh");
    if (!runbook.edited && !runbook.created) warn("ROI changed — document changes in docs/ops/roi_go_live_runbook.md");
  }
};
