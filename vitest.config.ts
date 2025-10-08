import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    // Global test configuration
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts', './apps/web/src/__tests__/setup.ts'],

    // Parallel execution
    pool: 'threads',
    poolOptions: {
      threads: {
        singleThread: false,
        minThreads: 1,
        maxThreads: 4, // Adjust based on CPU cores
      },
    },

    // Timeout configuration
    testTimeout: 30000, // 30 seconds per test
    hookTimeout: 30000,
    teardownTimeout: 10000,

    // Coverage configuration
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov', 'json-summary'],
      reportsDirectory: './coverage',
      thresholds: {
        global: {
          statements: 85,
          branches: 80,
          functions: 85,
          lines: 85,
        },
      },
      exclude: [
        'node_modules/',
        'src/__tests__/',
        '**/*.d.ts',
        '**/*.config.*',
        '**/mockData/',
        'dist/',
        '.next/',
        '__tests__/',
        '**/*.test.{js,ts,tsx}',
        '**/types/',
        '**/seedData.ts',
        '**/mocks/',
      ],
      clean: true,
    },

    // Reporters
    reporters: ['verbose', 'junit', 'html'],
    outputFile: {
      junit: './test-results/junit.xml',
      html: './test-results/index.html',
    },

    // File patterns
    include: ['**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'],
    exclude: ['node_modules', 'dist', '.next', 'coverage'],

    // Watch mode exclusions
    watchExclude: ['**/node_modules/**', '**/dist/**'],

    // Retry failed tests
    retry: 2,

    // Bail on first failure (CI only)
    bail: process.env.CI ? 1 : 0,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './apps/web/src'),
      '@tests': path.resolve(__dirname, './apps/web/src/__tests__'),
    },
  },
});
