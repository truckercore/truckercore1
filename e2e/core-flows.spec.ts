import { test, expect } from './utils/network';

test.describe('Map overlays', () => {
  test('shows clusters → expands → selects best recommendation', async ({ page }) => {
    await page.goto('/map');
    await expect(page.getByTestId('map-canvas')).toBeVisible();

    // Cluster bubble visible
    const cluster = page.getByTestId('cluster-bubble').first();
    await expect(cluster).toBeVisible();

    // Click cluster to expand
    await cluster.click();
    await expect(page.getByRole('dialog', { name: /stops nearby/i })).toBeVisible();

    // Best for you card present with factors
    const best = page.getByTestId('best-stop');
    await expect(best).toBeVisible();
    await expect(best.getByText(/conf/i)).toBeVisible();

    // Navigate to stop details
    await best.click();
    await expect(page).toHaveURL(/stop\/.+/);
    await expect(page.getByTestId('stop-details')).toBeVisible();
  });
});
