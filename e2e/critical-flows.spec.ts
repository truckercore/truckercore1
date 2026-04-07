import { test, expect } from '@playwright/test';

// Basic smoke E2E for critical flows
// Note: Requires app server running at E2E_BASE_URL (default http://localhost:3000)

test.describe('Critical user flows', () => {
  test('Landing page loads without errors', async ({ page }) => {
    const resp = await page.goto('/');
    expect(resp?.ok()).toBeTruthy();
    await expect(page).toHaveLoadState('domcontentloaded');
  });

  test('Navigate to any dashboard link if present', async ({ page }) => {
    await page.goto('/');
    const dashboardLink = page.locator('a:has-text("Dashboard")');
    const hasDashboard = await dashboardLink.count();
    if (hasDashboard > 0) {
      await dashboardLink.first().click();
      await expect(page).toHaveLoadState('domcontentloaded');
    } else {
      test.skip(true, 'Dashboard link not present in this build');
    }
  });
});
