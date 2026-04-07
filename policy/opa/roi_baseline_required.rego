package truckercore.roi

# Deny when exec_analytics entitlement is true but required baseline defaults are missing for the org
# Expected input example:
# {
#   "entitlements": { "exec_analytics": true },
#   "baseline_defaults_present": true
# }

deny["Baseline defaults missing for exec_analytics org"] {
  input.entitlements.exec_analytics
  not input.baseline_defaults_present
}
