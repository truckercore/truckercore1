package truckercore.ai

deny[msg] {
  input.module == "ai"
  input.probe_runtime_ms > 60000
  msg := "AI probe runtime exceeded 60s"
}

deny[msg] {
  input.module == "ai"
  input.health.p95_ms > 1200
  msg := sprintf("AI health p95 too high: %v ms", [input.health.p95_ms])
}
