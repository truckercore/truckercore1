package truckercore.roi

# deny if any exec_analytics org lacks an effective baseline
deny[msg] {
  some org
  input.exec_analytics_orgs[_] == org
  not input.effective_baselines[org]
  msg := sprintf("exec_analytics enabled but no effective baseline for org %v", [org])
}

# deny if no baseline defaults seeded
deny[msg] {
  count(input.baseline_defaults) == 0
  msg := "no baseline defaults seeded"
}
