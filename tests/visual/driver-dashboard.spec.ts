import { test, expect } from '@playwright/test';

// Visual regression tests for Driver Dashboard

test.describe('Driver Dashboard Visual Regression', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/driver/dashboard');
    await page.waitForLoadState('networkidle');
  });

  test('should match dashboard snapshot', async ({ page }) => {
    await expect(page).toHaveScreenshot('dashboard-full.png', {
      fullPage: true,
      animations: 'disabled',
    });
  });

  test('should match HOS panel snapshot', async ({ page }) => {
    const hosPanel = page.locator('.hos-panel');
    await expect(hosPanel).toHaveScreenshot('hos-panel.png');
  });

  test('should match load panel snapshot', async ({ page }) => {
    const loadPanel = page.locator('.load-panel');
    await expect(loadPanel).toHaveScreenshot('load-panel.png');
  });

  test('should match warning state', async ({ page }) => {
    await page.route('**/api/driver/*/hos', async (route) => {
      await route.fulfill({
        json: {
          entries: [],
          currentStatus: 'driving',
          limits: {
            drivingTimeRemaining: 15,
            onDutyWindowRemaining: 30,
          },
        },
      });
    });

    await page.reload();
    await page.waitForSelector('.warning-critical');

    const warnings = page.locator('.hos-warnings');
    await expect(warnings).toHaveScreenshot('warnings-critical.png');
  });

  test('should match offline mode', async ({ page, context }) => {
    await context.setOffline(true);
    await page.reload();

    const offlineIndicator = page.locator('.status-indicator.offline');
    await expect(offlineIndicator).toBeVisible();
    await expect(page).toHaveScreenshot('offline-mode.png');
  });

  test('should match POD modal', async ({ page }) => {
    // This assumes a complete button exists in the UI to open modal
    const completeBtn = page.locator('button:has-text("Complete")');
    if (await completeBtn.count()) {
      await completeBtn.first().click();
      await page.waitForSelector('.pod-modal');
      const modal = page.locator('.pod-modal');
      await expect(modal).toHaveScreenshot('pod-modal.png');
    } else {
      test.skip(true, 'Complete button not present');
    }
  });

  test('should match mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await expect(page).toHaveScreenshot('dashboard-mobile.png', { fullPage: true });
  });

  test('should match tablet viewport', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await expect(page).toHaveScreenshot('dashboard-tablet.png', { fullPage: true });
  });
});
