import { defineConfig, mergeConfig } from 'vitest/config';
import baseConfig from './vitest.config';

export default mergeConfig(
  baseConfig,
  defineConfig({
    test: {
      include: ['**/*.unit.{test,spec}.{ts,tsx,js,jsx}'],
      name: 'unit',
      testTimeout: 10000,
      pool: 'threads',
      poolOptions: {
        threads: {
          maxThreads: 8,
        },
      },
    },
  })
);
