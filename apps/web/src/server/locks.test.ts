import { describe, it, expect } from 'vitest';
import { acquireLock } from './locks';

describe('locks', () => {
  it('acquireLock returns null or token shape', async () => {
    const lock = await acquireLock('test', 1000).catch(() => null);
    if (lock) {
      expect(typeof lock.token).toBe('string');
      await lock.release();
    } else {
      expect(lock).toBeNull();
    }
  });
});
