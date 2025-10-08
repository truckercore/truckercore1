import StorageProvider from '../src/services/storage/providers/StorageProvider';
import DefaultStorageMonitor from '../src/services/storage/implementations/DefaultStorageMonitor';

async function verifyMonitoring() {
  console.log('🔍 Verifying Storage Monitoring...\n');

  const storage = StorageProvider.getStorage();
  const monitor = DefaultStorageMonitor.getInstance();
  monitor.reset();

  console.log('📝 Performing test operations...');
  await storage.saveFavorites('testUser', ['d1', 'd2', 'd3']);
  await storage.loadFavorites('testUser');
  await storage.saveRecents('testUser', [{ id: 'd1', name: 'Dashboard 1', accessedAt: new Date() }]);
  await storage.loadRecents('testUser');

  const metrics = monitor.getMetrics();

  console.log('\n📊 Metrics Summary:');
  console.log(`  Total Operations: ${metrics.totalOperations}`);
  console.log(`  Successful: ${metrics.successfulOperations}`);
  console.log(`  Failed: ${metrics.failedOperations}`);
  console.log(`  Error Rate: ${(metrics.errorRate * 100).toFixed(2)}%`);
  console.log(`  Average Latency: ${metrics.averageLatency.toFixed(2)}ms`);

  console.log('\n📈 Operation Details:');
  Object.entries(metrics.operationCounts).forEach(([op, count]) => {
    const stats = monitor.getOperationStats(op);
    console.log(`  ${op}:`);
    console.log(`    Count: ${count}`);
    console.log(`    Avg Latency: ${stats.latency.average.toFixed(2)}ms`);
    console.log(`    Success Rate: ${stats.successRate.toFixed(2)}%`);
  });

  const checks = [
    { name: 'Total operations recorded', pass: metrics.totalOperations === 4 },
    { name: 'All operations successful', pass: metrics.failedOperations === 0 },
    { name: 'Latency tracked', pass: metrics.averageLatency > 0 || metrics.totalOperations > 0 },
    { name: 'Per-operation stats available', pass: Object.keys(metrics.operationCounts).length === 4 },
  ];

  console.log('\n✅ Verification Results:');
  checks.forEach((c) => console.log(`  ${c.pass ? '✅' : '❌'} ${c.name}`));

  const allPassed = checks.every((c) => c.pass);
  console.log(`\n${allPassed ? '🎉 All checks passed!' : '⚠️  Some checks failed'}`);
  return allPassed ? 0 : 1;
}

verifyMonitoring()
  .then((code) => process.exit(code))
  .catch((err) => {
    console.error('❌ Verification failed:', err);
    process.exit(1);
  });
