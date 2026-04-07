import { test, expect } from './utils/network';

test.describe('Crowd report', () => {
  test('submit parking signal and see toast + list refresh', async ({ page }) => {
    await page.goto('/map');
    await expect(page.getByTestId('map-canvas')).toBeVisible();

    // Open report sheet
    await page.getByRole('button', { name: /report/i }).click();
    await expect(page.getByRole('dialog', { name: /report status/i })).toBeVisible();

    // Select parking: Open
    await page.getByRole('radio', { name: /open/i }).check();
    await page.getByRole('button', { name: /submit/i }).click();

    // Toast visible
    await expect(page.getByText(/recorded open/i)).toBeVisible();

    // Overlay/badge should reflect recent update (confidence/recency)
    await expect(page.getByTestId('parking-badge')).toContainText(/open/i);
  });

  test('error path shows fallback UI', async ({ page }) => {
    await page.goto('/map?forceError=500'); // routed to trigger error path
    await page.getByRole('button', { name: /report/i }).click();
    await page.getByRole('radio', { name: /open/i }).check();
    await page.getByRole('button', { name: /submit/i }).click();
    await expect(page.getByText(/couldn’t submit/i)).toBeVisible();
  });
});
