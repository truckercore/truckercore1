# Production Validation Suite

## Running Validations

```
# Run all validations
npm run validate

# Run with detailed report
npm run validate -- --report

# Run specific category
npm run validate -- --category=security

# Quick/basic validations (critical/high only)
npm run validate:quick

# Comprehensive validations (all)
npm run validate:full

# Critical-only validations
npm run validate:critical
```

## Exit Codes

- 0: All checks passed (or only warnings)
- 1: Validation failed
- 2: Critical error
- 3: Configuration error
- 4: Dependency error

## Configuration

Create `.validation.config.js` in the repository root to customize checks, thresholds, and notifications.

Example:

```
module.exports = {
  checks: {
    environment: { enabled: true, severity: 'critical' },
    dependencies: { enabled: true, severity: 'high' },
    security: { enabled: true, severity: 'critical' },
    performance: { enabled: false, severity: 'low' }
  },
  thresholds: {
    testCoverage: 80,
    buildTime: 300,
    bundleSize: 5000
  },
  ignore: [
    'OPTIONAL_ENV_VAR',
    'DEV_ONLY_CONFIG'
  ],
  notification: {
    // slack: { webhook: 'https://hooks.slack.com/services/...' },
    // monitoring: { endpoint: 'https://monitoring.example.com/validate' }
  }
};
```

## Reports

Use `--report` to generate a markdown report in the `reports/` directory. Use `--output=custom.md` to set the filename.

## Adding Custom Checks

The validation script is modular. Add a new category by extending the `registry` in `scripts/validate.js` and implementing a function that returns a CategoryResult.
