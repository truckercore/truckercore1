import { test as base } from '@playwright/test';

export const test = base.extend({
  context: async ({ context }, use) => {
    await context.addInitScript(() => {
      // deterministic time
      // @ts-ignore
      Date.now = () => 1700000000000;
    });
    await context.route('**/*', (route) => {
      const url = route.request().url();
      const allow = /localhost:3\d{3}|127\.0\.0\.1:54321|supabase\.co|your-cdn|http:\/\/127\.0\.0\.1:4001/.test(url);
      return allow ? route.continue() : route.abort();
    });
    await use(context);
  },
});
export const expect = base.expect;
