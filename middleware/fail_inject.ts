// middleware/fail_inject.ts
export function maybeFail() {
  if (process.env.FAIL_INJECT === '1' && Math.random() < 0.01) {
    const e: any = new Error('synthetic_500');
    e.status = 500;
    throw e;
  }
}
