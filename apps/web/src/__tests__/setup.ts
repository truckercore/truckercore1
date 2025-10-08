import { afterAll, afterEach, beforeAll, vi, expect } from 'vitest';
import { cleanup } from '@testing-library/react';
import '@testing-library/jest-dom';

// Extend matchers
import * as matchers from '@testing-library/jest-dom/matchers';
expect.extend(matchers);

// Mock environment variables
process.env.NEXT_PUBLIC_API_URL = 'http://localhost:3000';
process.env.NEXT_PUBLIC_SUPABASE_URL = 'http://localhost:54321';
process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = 'test-key';

// Global test utilities
// ResizeObserver mock
// @ts-expect-error test env
global.ResizeObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}));

// IntersectionObserver mock (if not already provided by root setup)
if (!(global as any).IntersectionObserver) {
  // @ts-expect-error test env
  global.IntersectionObserver = vi.fn().mockImplementation(() => ({
    observe: vi.fn(),
    unobserve: vi.fn(),
    disconnect: vi.fn(),
  }));
}

// Mock fetch globally
// @ts-expect-error test env
global.fetch = global.fetch || vi.fn();

// Mock geolocation
const mockGeolocation = {
  getCurrentPosition: vi.fn(),
  watchPosition: vi.fn(),
  clearWatch: vi.fn(),
};

Object.defineProperty(global.navigator, 'geolocation', {
  writable: true,
  value: mockGeolocation,
});

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {};

  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => {
      store[key] = value.toString();
    },
    removeItem: (key: string) => {
      delete store[key];
    },
    clear: () => {
      store = {};
    },
  };
})();

Object.defineProperty(window, 'localStorage', {
  value: localStorageMock,
});

// Cleanup after each test
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
  localStorageMock.clear();
});

// Reset all mocks after all tests
afterAll(() => {
  vi.resetAllMocks();
});

// Suppress console errors in tests (optional)
const originalError = console.error;
beforeAll(() => {
  // @ts-expect-error variadic
  console.error = (...args: any[]) => {
    if (
      typeof args[0] === 'string' &&
      (args[0].includes('Warning: ReactDOM.render') ||
       args[0].includes('Not implemented: HTMLFormElement.prototype.submit'))
    ) {
      return;
    }
    // @ts-expect-error variadic
    originalError.call(console, ...args);
  };
});

afterAll(() => {
  console.error = originalError;
});
