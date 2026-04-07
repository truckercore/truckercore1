import { describe, it, expect } from 'vitest';
import { tokenBucket } from './rateLimit';

// Note: requires Redis to be reachable via REDIS_URL for full test; this is a smoke test.
describe('rateLimit', () => {
  it('exposes tokenBucket', () => {
    expect(typeof tokenBucket).toBe('function');
  });
});
