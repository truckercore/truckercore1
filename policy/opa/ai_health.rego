package truckercore.ai

# Fail if ETA p95 exceeds SLO
deny[msg] {
  input.health.p95_ms > 1200
  msg := sprintf("AI health p95 too high: %v ms (> 1200)", [input.health.p95_ms])
}

# Probe runtime quota (60s)
deny[msg] {
  input.module_probe_runtime_ms > 60000
  msg := sprintf("AI probe runtime exceeded 60s quota (got %v ms)", [input.module_probe_runtime_ms])
}
