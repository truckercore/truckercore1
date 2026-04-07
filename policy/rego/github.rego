package policy.github

deny[msg] {
  input.workflow.permissions.id_token == "write"
  input.workflow.event == "pull_request"
  msg := "GITHUB_TOKEN write denied on PRs"
}
