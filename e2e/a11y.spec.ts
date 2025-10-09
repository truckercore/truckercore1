import { test, expect } from './utils/network';
import AxeBuilder from '@axe-core/playwright';

test('dashboard has no critical a11y issues', async ({ page }) => {
  await page.goto('/dashboard');
  const results = await new AxeBuilder({ page }).analyze();
  const critical = results.violations.filter(v => v.impact === 'critical');
  expect(critical, JSON.stringify(critical, null, 2)).toHaveLength(0);
});
