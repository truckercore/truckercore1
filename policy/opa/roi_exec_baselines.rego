package truckercore.roi

deny[msg] {
  some org
  input.exec_analytics_orgs[_] == org
  not input.effective_baselines[org]
  msg := sprintf("exec_analytics enabled but no effective baseline for org %v", [org])
}
