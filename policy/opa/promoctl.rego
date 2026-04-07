package truckercore.promoctl

deny[msg] {
  input.module == "promoctl"
  input.p95_ms > 800
  msg := sprintf("Promotion p95 too high: %d ms", [input.p95_ms])
}

# Placeholder to be wired by CI supplying input.state.invalid_transition
# For now, CI can set input.state.invalid_transition=true upon detection
# in its own checks; this rule will then raise a deny.
deny[msg] {
  input.state.invalid_transition
  msg := "Illegal rollout state transition detected"
}
