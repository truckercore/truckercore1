module.exports = {
  checks: {
    environment: { enabled: true, severity: 'critical' },
    dependencies: { enabled: true, severity: 'high' },
    configuration: { enabled: true, severity: 'high' },
    security: { enabled: true, severity: 'critical' },
    performance: { enabled: false, severity: 'low' },
    infrastructure: { enabled: true, severity: 'high' },
    tests: { enabled: true, severity: 'medium' }
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
    // email: { recipients: ['ops@example.com'] },
    // monitoring: { endpoint: 'https://monitoring.example.com/validate' }
  }
};