import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

interface TestSuiteResult {
  name: string;
  duration: number;
  passed: number;
  failed: number;
  skipped: number;
  total: number;
}

async function monitorTestExecution() {
  console.log('📊 Test Execution Monitor\n');

  const suites = [
    { name: 'Unit Tests', command: 'npm run test:unit:ci' },
    { name: 'Integration Tests', command: 'npm run test:integration:ci' },
    { name: 'E2E Tests', command: 'npm run test:e2e' },
  ];

  const results: TestSuiteResult[] = [];

  for (const suite of suites) {
    console.log(`\n🏃 Running ${suite.name}...`);
    const start = Date.now();

    try {
      const { stdout } = await execAsync(suite.command, {
        timeout: 300000, // 5 minutes max per suite
      });

      const duration = Date.now() - start;
      const parsed = parseTestOutput(stdout);

      results.push({
        name: suite.name,
        duration,
        ...parsed,
      });

      console.log(`✅ ${suite.name} completed in ${(duration / 1000).toFixed(2)}s`);
    } catch (error: any) {
      const duration = Date.now() - start;
      console.error(`❌ ${suite.name} failed after ${(duration / 1000).toFixed(2)}s`);
      console.error(error.message);

      results.push({
        name: suite.name,
        duration,
        passed: 0,
        failed: 1,
        skipped: 0,
        total: 1,
      });
    }
  }

  // Print summary
  printSummary(results);

  // Exit with appropriate code
  const hasFailures = results.some(r => r.failed > 0);
  process.exit(hasFailures ? 1 : 0);
}

function parseTestOutput(output: string): Omit<TestSuiteResult, 'name' | 'duration'> {
  // Parse test output - adjust regex based on your test runner
  const passedMatch = output.match(/(\d+)\s+passed/);
  const failedMatch = output.match(/(\d+)\s+failed/);
  const skippedMatch = output.match(/(\d+)\s+skipped/);

  const passed = passedMatch ? parseInt(passedMatch[1]) : 0;
  const failed = failedMatch ? parseInt(failedMatch[1]) : 0;
  const skipped = skippedMatch ? parseInt(skippedMatch[1]) : 0;

  return {
    passed,
    failed,
    skipped,
    total: passed + failed + skipped,
  };
}

function printSummary(results: TestSuiteResult[]) {
  console.log('\n\n📈 Test Execution Summary\n');
  console.log('─'.repeat(80));

  let totalPassed = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  let totalDuration = 0;

  results.forEach(result => {
    const status = result.failed === 0 ? '✅' : '❌';
    console.log(
      `${status} ${result.name.padEnd(25)} | ` +
      `Passed: ${result.passed.toString().padStart(4)} | ` +
      `Failed: ${result.failed.toString().padStart(4)} | ` +
      `Duration: ${(result.duration / 1000).toFixed(2)}s`
    );

    totalPassed += result.passed;
    totalFailed += result.failed;
    totalSkipped += result.skipped;
    totalDuration += result.duration;
  });

  console.log('─'.repeat(80));
  console.log(
    `TOTAL:                    | ` +
    `Passed: ${totalPassed.toString().padStart(4)} | ` +
    `Failed: ${totalFailed.toString().padStart(4)} | ` +
    `Duration: ${(totalDuration / 1000).toFixed(2)}s`
  );
  console.log('─'.repeat(80));

  const successRate = (totalPassed + totalFailed) > 0
    ? ((totalPassed / (totalPassed + totalFailed)) * 100).toFixed(2)
    : '0.00';

  console.log(`\n📊 Success Rate: ${successRate}%`);

  if (totalFailed > 0) {
    console.log(`\n⚠️  ${totalFailed} test(s) failed`);
  } else {
    console.log('\n🎉 All tests passed!');
  }
}

// Run if called directly
if (require.main === module) {
  monitorTestExecution().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}
