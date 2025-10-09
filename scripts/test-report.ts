import * as fs from 'fs';

interface TestResultSummary {
  numTotalTests: number;
  numPassedTests: number;
  numFailedTests: number;
  numPendingTests: number;
}

interface CoverageSummary {
  total: {
    statements: { pct: number };
    branches: { pct: number };
    functions: { pct: number };
    lines: { pct: number };
  };
}

function generateTestReport() {
  console.log('📊 Generating Test Report...\n');

  const testResultsPath = './test-results.json';
  const coveragePath = './coverage/coverage-summary.json';

  let report = '# Test Report\n\n';
  report += `**Generated:** ${new Date().toLocaleString()}\n\n`;

  // Test Results
  if (fs.existsSync(testResultsPath)) {
    const content = JSON.parse(fs.readFileSync(testResultsPath, 'utf8')) as any;
    const results: TestResultSummary = {
      numTotalTests: content.numTotalTests ?? 0,
      numPassedTests: content.numPassedTests ?? 0,
      numFailedTests: content.numFailedTests ?? 0,
      numPendingTests: content.numPendingTests ?? 0,
    };

    report += '## Test Execution Summary\n\n';
    report += `- ✅ **Passed:** ${results.numPassedTests}\n`;
    report += `- ❌ **Failed:** ${results.numFailedTests}\n`;
    report += `- ⏸️  **Pending:** ${results.numPendingTests}\n`;
    report += `- 📝 **Total:** ${results.numTotalTests}\n\n`;

    const passRate = results.numTotalTests ? ((results.numPassedTests / results.numTotalTests) * 100).toFixed(2) : '0.00';
    const emoji = parseFloat(passRate) === 100 ? '🎉' : parseFloat(passRate) >= 90 ? '✅' : '⚠️';
    report += `${emoji} **Pass Rate:** ${passRate}%\n\n`;
  } else {
    report += 'No test results (test-results.json) found.\n\n';
  }

  // Coverage Results
  if (fs.existsSync(coveragePath)) {
    const coverage: CoverageSummary = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));
    const { total } = coverage;

    report += '## Coverage Summary\n\n';
    report += '| Metric | Coverage | Status |\n';
    report += '|--------|----------|--------|\n';
    report += `| Statements | ${total.statements.pct}% | ${total.statements.pct >= 80 ? '✅' : '⚠️'} |\n`;
    report += `| Branches | ${total.branches.pct}% | ${total.branches.pct >= 75 ? '✅' : '⚠️'} |\n`;
    report += `| Functions | ${total.functions.pct}% | ${total.functions.pct >= 80 ? '✅' : '⚠️'} |\n`;
    report += `| Lines | ${total.lines.pct}% | ${total.lines.pct >= 80 ? '✅' : '⚠️'} |\n\n`;

    const avgCoverage = (
      (total.statements.pct + total.branches.pct + total.functions.pct + total.lines.pct) / 4
    ).toFixed(2);

    const coverageEmoji = parseFloat(avgCoverage) >= 80 ? '🎉' : parseFloat(avgCoverage) >= 70 ? '✅' : '⚠️';
    report += `${coverageEmoji} **Average Coverage:** ${avgCoverage}%\n\n`;
  } else {
    report += 'No coverage summary (coverage/coverage-summary.json) found.\n\n';
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

  const coverage: CoverageSummary = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));
  const { total } = coverage;

  const thresholds = {
    statements: 80,
    branches: 75,
    functions: 80,
    lines: 80,
  } as const;

  let failed = false;

  console.log('\n🔍 Checking coverage thresholds...\n');

  for (const [metric, threshold] of Object.entries(thresholds)) {
    const actual = (total as any)[metric].pct as number;
    const status = actual >= (threshold as number) ? '✅' : '❌';
    const message = `${status} ${metric}: ${actual}% (threshold: ${threshold}%)`;
    console.log(message);
    if (actual < (threshold as number)) failed = true;
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
