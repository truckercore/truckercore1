package policy.branch

deny[msg] {
  not input.branch.protection.required_reviewers
  msg := "Required reviewers missing"
}

deny[msg] {
  not input.branch.protection.required_status_checks
  msg := "Required status checks missing"
}
