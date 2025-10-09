/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  transform: {
    '^.+\\.(t|j)sx?$': [
      'ts-jest',
      {
        useESM: true,
        tsconfig: {
          target: 'ES2020',
          module: 'ESNext',
          esModuleInterop: true,
          allowJs: true,
          moduleResolution: 'Node',
          resolveJsonModule: true,
          isolatedModules: true,
          noEmit: true
        }
      }
    ]
  },
  extensionsToTreatAsEsm: ['.ts'],
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'mjs', 'cjs', 'json'],
  testMatch: ['**/tests/**/*.spec.ts'],
  verbose: true,
  // Allow importing .mjs files from TS tests
  moduleNameMapper: {
    '^(.*)\\.mjs$': '$1.mjs'
  }
};
