# Dashboard: CI Security

Charts
- SAST findings by severity over time (Semgrep/CodeQL)
- SCA findings by severity (npm audit)
- Canary webhook test pass/fail trend
- Secret scan findings trend

KPIs
- Mean time to remediate by severity (Critical, High, Medium, Low)
- Open security PRs and age

Links
- Workflows: .github/workflows/pr.yml, nightly-security.yml, ci-security.yml
- Reports: SARIF uploads, audit.json artifacts
- Alerts: Security gates failing, secret-scanning findings
