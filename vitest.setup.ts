import '@testing-library/jest-dom';
import 'fake-indexeddb/auto';
import { afterEach, vi } from 'vitest';
import { cleanup } from '@testing-library/react';

// Cleanup after each test
afterEach(() => {
  cleanup();
});

// Mock Notification API
// @ts-expect-error - global augmentation for tests
global.Notification = {
  permission: 'granted',
  requestPermission: vi.fn().mockResolvedValue('granted'),
} as any;

// Mock fetch if not provided
if (!(global as any).fetch) {
  // @ts-expect-error - test environment
  global.fetch = vi.fn();
}

// Mock window.matchMedia
if (typeof window !== 'undefined' && !window.matchMedia) {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: vi.fn().mockImplementation((query: string) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: vi.fn(), // deprecated
      removeListener: vi.fn(), // deprecated
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })),
  });
}

// Mock IntersectionObserver
if (!(global as any).IntersectionObserver) {
  // @ts-expect-error - test shim
  global.IntersectionObserver = class IntersectionObserver {
    // eslint-disable-next-line @typescript-eslint/no-useless-constructor
    constructor() {}
    disconnect() {}
    observe() {}
    unobserve() {}
    takeRecords() { return []; }
  } as any;
}
