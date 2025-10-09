package truckercore.endpoints

deny["decisions echo must be admin-only"] {
  input.diff.files[_].path == "functions/ops/echo_decisions/index.ts"
  not input.includes_text["requireAdmin("]
}
