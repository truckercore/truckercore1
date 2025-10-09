import { test as base } from '@playwright/test';
export const test = base.extend({
  storageState: async ({}, use) => {
    await use('e2e/.auth/storage-state.json');
  },
});
export const expect = base.expect;
