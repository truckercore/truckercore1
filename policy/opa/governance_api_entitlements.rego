package truckercore.governance

default deny = []

deny[msg] {
  input.api_new == true
  not input.entitlement_check
  msg := "API added without entitlement check"
}

deny[msg] {
  input.runbook_entry_missing == true
  msg := "Missing runbook entry for new API/module"
}
