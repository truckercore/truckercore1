package truckercore.promoctl

deny[msg] {
  input.state_transition.old.strategy == "canary"
  input.state_transition.new.strategy == "single"
  input.state_transition.old.candidate_version_id != input.state_transition.new.active_version_id
  msg := "finish must promote current candidate"
}

deny[msg] {
  input.state_transition.new.strategy == "canary"
  input.state_transition.new.canary_pct < input.state_transition.old.canary_pct
  msg := "canary pct must be monotonic"
}
