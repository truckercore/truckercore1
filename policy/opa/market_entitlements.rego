package truckercore.market

deny[msg] {
  input.endpoint == "tier2_predictive"
  not input.entitlements["tier2_predictive"]
  msg := "tier2 endpoint without entitlement"
}
