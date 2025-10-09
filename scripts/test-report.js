const fs = require('fs');

function generateTestReport() {
  console.log('📊 Generating Test Report...\n');

  const testResultsPath = './test-results.json';
  const coveragePath = './coverage/coverage-summary.json';

  let report = '# Test Report\n\n';
  report += `**Generated:** ${new Date().toLocaleString()}\n\n`;

  // Test Results
  if (fs.existsSync(testResultsPath)) {
    try {
      const results = JSON.parse(fs.readFileSync(testResultsPath, 'utf8'));
      const numTotalTests = results.numTotalTests ?? 0;
      const numPassedTests = results.numPassedTests ?? 0;
      const numFailedTests = results.numFailedTests ?? 0;
      const numPendingTests = results.numPendingTests ?? 0;

      report += '## Test Execution Summary\n\n';
      report += `- ✅ **Passed:** ${numPassedTests}\n`;
      report += `- ❌ **Failed:** ${numFailedTests}\n`;
      report += `- ⏸️  **Pending:** ${numPendingTests}\n`;
      report += `- 📝 **Total:** ${numTotalTests}\n\n`;

      const passRate = numTotalTests ? ((numPassedTests / numTotalTests) * 100).toFixed(2) : '0.00';
      const passRateNum = parseFloat(passRate);
      const emoji = passRateNum === 100 ? '🎉' : passRateNum >= 90 ? '✅' : '⚠️';
      report += `${emoji} **Pass Rate:** ${passRate}%\n\n`;
    } catch (e) {
      report += '> ⚠️ Could not parse test-results.json\n\n';
    }
  } else {
    report += '> ℹ️ No test results found (test-results.json missing).\n\n';
  }

  // Coverage Results
  if (fs.existsSync(coveragePath)) {
    try {
      const coverage = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));
      const total = coverage.total || {};

      const s = total.statements?.pct ?? 0;
      const b = total.branches?.pct ?? 0;
      const f = total.functions?.pct ?? 0;
      const l = total.lines?.pct ?? 0;

      report += '## Coverage Summary\n\n';
      report += '| Metric | Coverage | Status |\n';
      report += '|--------|----------|--------|\n';
      report += `| Statements | ${s}% | ${s >= 80 ? '✅' : '⚠️'} |\n`;
      report += `| Branches | ${b}% | ${b >= 75 ? '✅' : '⚠️'} |\n`;
      report += `| Functions | ${f}% | ${f >= 80 ? '✅' : '⚠️'} |\n`;
      report += `| Lines | ${l}% | ${l >= 80 ? '✅' : '⚠️'} |\n\n`;

      const avg = ((s + b + f + l) / 4).toFixed(2);
      const avgNum = parseFloat(avg);
      const coverageEmoji = avgNum >= 80 ? '🎉' : avgNum >= 70 ? '✅' : '⚠️';
      report += `${coverageEmoji} **Average Coverage:** ${avg}%\n\n`;
    } catch (e) {
      report += '> ⚠️ Could not parse coverage/coverage-summary.json\n\n';
    }
  } else {
    report += '> ℹ️ No coverage summary found.\n\n';
  }

  const reportPath = './test-report.md';
  fs.writeFileSync(reportPath, report);

  console.log('✅ Report generated successfully!');
  console.log(`📄 Report saved to: ${reportPath}\n`);
  console.log(report);

  return report;
}

function checkCoverageThresholds() {
  const coveragePath = './coverage/coverage-summary.json';

  if (!fs.existsSync(coveragePath)) {
    console.error('❌ Coverage file not found!');
    process.exit(1);
  }

  const coverage = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));
  const total = coverage.total || {};

  const thresholds = {
    statements: 80,
    branches: 75,
    functions: 80,
    lines: 80,
  };

  let failed = false;

  console.log('\n🔍 Checking coverage thresholds...\n');

  for (const [metric, threshold] of Object.entries(thresholds)) {
    const actual = total[metric]?.pct ?? 0;
    const status = actual >= threshold ? '✅' : '❌';
    const message = `${status} ${metric}: ${actual}% (threshold: ${threshold}%)`;
    console.log(message);
    if (actual < threshold) failed = true;
  }

  if (failed) {
    console.log('\n❌ Coverage thresholds not met!\n');
    process.exit(1);
  }

  console.log('\n✅ All coverage thresholds met!\n');
}

const command = process.argv[2];
if (command === 'check') {
  checkCoverageThresholds();
} else {
  generateTestReport();
}
