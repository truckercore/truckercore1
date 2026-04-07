package truckercore.ai

deny[msg] {
  input.diff.ai_changed
  not input.artifacts.endpoint_registry_present
  msg := "AI endpoints changed but scripts/ai_endpoints.json not updated"
}

deny[msg] {
  input.module == "ai"
  input.probe_runtime_ms > 60000
  msg := "AI probe runtime exceeded 60s budget"
}
