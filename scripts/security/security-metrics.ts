import { execSync } from 'child_process';
import * as fs from 'fs';

interface AuditMetadata {
  vulnerabilities: {
    critical: number;
    high: number;
    moderate: number;
    low: number;
    info: number;
    total: number;
  };
  dependencies: number;
  devDependencies: number;
  optionalDependencies: number;
  totalDependencies: number;
}

interface AuditReport {
  auditReportVersion: number;
  vulnerabilities: Record<string, any>;
  metadata: AuditMetadata;
}

function runSecurityMetrics() {
  try {
    console.log('🔍 Running security audit...\n');

    // Run npm audit
    let auditOutput: string;
    try {
      auditOutput = execSync('npm audit --json', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (error: any) {
      // npm audit exits with code 1 if vulnerabilities found; capture stdout
      auditOutput = error?.stdout?.toString?.() || '';
    }

    if (!auditOutput) {
      console.error('❌ No output from npm audit. Ensure npm is installed and package.json exists.');
      process.exit(1);
    }

    const auditReport: AuditReport = JSON.parse(auditOutput);
    const { metadata } = auditReport;

    // Display results
    console.log('📊 Security Metrics Report');
    console.log('═'.repeat(50));
    console.log(`\n🔴 Critical: ${metadata.vulnerabilities.critical}`);
    console.log(`🟠 High:     ${metadata.vulnerabilities.high}`);
    console.log(`🟡 Moderate: ${metadata.vulnerabilities.moderate}`);
    console.log(`🟢 Low:      ${metadata.vulnerabilities.low}`);
    console.log(`ℹ️  Info:     ${metadata.vulnerabilities.info}`);
    console.log(`\n📦 Total Dependencies: ${metadata.totalDependencies}`);
    console.log(`   - Production: ${metadata.dependencies}`);
    console.log(`   - Development: ${metadata.devDependencies}`);

    // Save report
    const reportPath = 'security-metrics.json';
    fs.writeFileSync(reportPath, JSON.stringify(auditReport, null, 2));
    console.log(`\n✅ Detailed report saved to ${reportPath}`);

    // Exit with error if critical or high vulnerabilities found
    if (metadata.vulnerabilities.critical > 0 || metadata.vulnerabilities.high > 0) {
      console.log('\n❌ Action required: Critical or high vulnerabilities detected!');
      process.exit(1);
    }

    console.log('\n✅ No critical or high vulnerabilities found!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error running security metrics:', error);
    process.exit(1);
  }
}

runSecurityMetrics();
