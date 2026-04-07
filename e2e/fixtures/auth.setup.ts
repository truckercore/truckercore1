import { test as setup, expect } from '@playwright/test';

const STORAGE_STATE = 'e2e/.auth/storage-state.json';

setup('authenticate and save storage', async ({ page }) => {
  const base = process.env.E2E_BASE_URL ?? 'http://localhost:3000';
  const user = process.env.E2E_USER!;
  const pass = process.env.E2E_PASS!;

  await page.goto(`${base}/auth/login`);
  await page.fill('input[name="email"]', user);
  await page.fill('input[name="password"]', pass);
  await page.click('button[type="submit"]');
  await page.waitForURL(`${base}/dashboard`, { timeout: 10000 });
  await expect(page).toHaveURL(/dashboard/);

  await page.context().storageState({ path: STORAGE_STATE });
});
