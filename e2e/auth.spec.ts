import { test, expect } from './utils/network';

test.describe('Auth', () => {
  test('login / logout (valid creds)', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill(process.env.E2E_USER!);
    await page.getByLabel('Password').fill(process.env.E2E_PASS!);
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL(/dashboard/);
    await page.getByRole('button', { name: /logout/i }).click();
    await expect(page).toHaveURL(/login/);
  });

  test('login fails (invalid creds)', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill('bad@example.com');
    await page.getByLabel('Password').fill('wrong');
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page.getByText(/invalid/i)).toBeVisible();
  });
});
