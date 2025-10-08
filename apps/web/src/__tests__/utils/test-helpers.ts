import { render, RenderOptions } from '@testing-library/react';
import { ReactElement, ReactNode, createElement } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { vi } from 'vitest';

// Create a custom render function with providers
export function renderWithProviders(
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>
) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        cacheTime: 0,
      },
      mutations: {
        retry: false,
      },
    },
  });

  function Wrapper({ children }: { children: ReactNode }) {
    return createElement(QueryClientProvider, { client: queryClient }, children);
  }

  return render(ui, { wrapper: Wrapper as any, ...options });
}

// Wait for a condition with timeout
export async function waitForCondition(
  condition: () => boolean | Promise<boolean>,
  timeout: number = 5000,
  interval: number = 100
): Promise<void> {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    if (await condition()) {
      return;
    }
    await new Promise(resolve => setTimeout(resolve, interval));
  }

  throw new Error('Condition not met within timeout');
}

// Mock API response helper
export function mockApiResponse<T>(data: T, delay: number = 0) {
  return new Promise<T>((resolve) => {
    setTimeout(() => resolve(data), delay);
  });
}

// Create mock file for upload tests
export function createMockFile(
  name: string = 'test.pdf',
  size: number = 1024,
  type: string = 'application/pdf'
): File {
  const blob = new Blob(['test content'], { type });
  return new File([blob], name, { type });
}

// Mock Supabase client
export function createMockSupabaseClient() {
  return {
    from: vi.fn().mockReturnThis(),
    select: vi.fn().mockReturnThis(),
    insert: vi.fn().mockReturnThis(),
    update: vi.fn().mockReturnThis(),
    delete: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    single: vi.fn(),
    auth: {
      getSession: vi.fn(),
      signIn: vi.fn(),
      signOut: vi.fn(),
    },
    storage: {
      from: vi.fn().mockReturnThis(),
      upload: vi.fn(),
      download: vi.fn(),
    },
  };
}

// Performance testing helper
export function measurePerformance(fn: () => void | Promise<void>) {
  const start = performance.now();
  const result = fn();
  
  if (result instanceof Promise) {
    return result.then(() => performance.now() - start);
  }
  
  return performance.now() - start;
}

// Retry helper for flaky tests
export async function retry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  delay: number = 100
): Promise<T> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  throw new Error('Max retries exceeded');
}

// Database cleanup helper
export async function cleanupTestData(tables: string[]) {
  // Implementation depends on your database setup
  for (const _table of tables) {
    // await supabase.from(table).delete().match({});
  }
}
