import { defineConfig, mergeConfig } from 'vitest/config';
import baseConfig from './vitest.config';

export default mergeConfig(
  baseConfig,
  defineConfig({
    test: {
      include: ['**/*.integration.{test,spec}.{ts,tsx,js,jsx}'],
      name: 'integration',
      testTimeout: 60000,
      hookTimeout: 60000,
      pool: 'threads',
      poolOptions: {
        threads: {
          maxThreads: 4, // Fewer threads for integration tests
        },
      },
      sequence: {
        concurrent: false, // Run integration tests sequentially
      },
    },
  })
);
