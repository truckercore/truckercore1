package truckercore.identity

deny[msg] {
  input.module == "identity"
  input.probe_runtime_ms > 60000
  msg := "Identity probes exceeded 60s budget"
}
