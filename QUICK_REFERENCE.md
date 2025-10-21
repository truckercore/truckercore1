# Infrastructure Quick Reference

## 🧪 Testing Commands

```
# Run tests (watch mode)
npm test

# Run once
npm run test:run

# With coverage
npm run test:coverage

# View HTML report
npm run coverage:open

# Check thresholds
npm run coverage:check
```

## 🔐 Security Commands

```
# Check vulnerabilities
npm audit

# With threshold
npm run audit:check

# Detailed metrics
npm run security:metrics

# Check updates
npm outdated
```

## 🔧 Validation Commands

```
./verify-setup.sh              # Quick check (~30s)
./validate-implementation.sh   # Full validation (~2min)
./scripts/health-check.sh      # Health check (~2-5min)
./scripts/status-dashboard.sh  # Status display (continuous)
./run-all-validations.sh       # All checks (orchestrator)
```

## 🚀 Deployment

```
./pre-deployment-checklist.sh  # Pre-flight check
./deploy.sh                    # Full deployment (already present)
```

## 📊 Coverage Thresholds

- Statements: ≥80%
- Branches: ≥75%
- Functions: ≥80%
- Lines: ≥80%

## 🤖 Automated Workflows

- Tests: Every push/PR
- Security audit: Daily at 9 AM UTC
- Dependabot: Weekly (Monday 9 AM UTC)

## 🆘 Troubleshooting

```
Tests fail
rm -rf node_modules && npm ci && npm run test:run

Coverage low
npm run coverage:open  # View HTML report

VSCode Vitest not working
Reload window (Cmd/Ctrl+Shift+P → "Reload Window")
Check Output panel: "Vitest"
```

## 📞 Useful Links

- Actions: https://github.com/<user>/<repo>/actions
- Dependabot: https://github.com/<user>/<repo>/security/dependabot
- Security: https://github.com/<user>/<repo>/security
