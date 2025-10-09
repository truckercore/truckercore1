package truckercore.clarifications

deny[msg] {
  input.module == "SSO/JWKS"
  not input.answers.jwks_ttl
  msg := "JWKS TTL not specified"
}

deny[msg] {
  input.module == "SCIM"
  not input.answers.bulk_deactivate_cap
  msg := "SCIM bulk deactivate cap not set"
}

deny[msg] {
  input.module == "AI Ranking"
  count(input.answers.required_factors) < 3
  msg := "AI ranking requires at least 3 factors"
}
