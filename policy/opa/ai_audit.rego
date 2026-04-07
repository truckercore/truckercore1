package truckercore.ai

deny[msg] {
  input.pr_changes.function_files[_]
  endswith(input.pr_changes.function_files[_], "/ai_ct/predict_eta/index.ts")
  not input.has_audit_logging
  msg := "AI decisions must be logged to ai_decision_audit"
}