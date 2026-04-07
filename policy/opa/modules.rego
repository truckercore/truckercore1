package truckercore.modules

# baseline regression guard
p95_regression(msg) {
  input.current.p95_ms > input.baseline.p95_ms * 1.25
  msg := sprintf("p95 regression: current=%v baseline=%v", [input.current.p95_ms, input.baseline.p95_ms])
}

# probe quota
deny_quota[msg] {
  input.module_probe_runtime_ms > 60000
  msg := "probe runtime exceeded 60s quota"
}
