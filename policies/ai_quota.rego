package truckercore.modules

deny_quota[msg] {
  input.module == "ai"
  input.probe_runtime_ms > 60000
  msg := "AI probe runtime exceeded 60s"
}
