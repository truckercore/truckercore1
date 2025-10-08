export class PerformanceMonitor {
  private static instance: PerformanceMonitor;
  private marks: Map<string, number> = new Map();

  private constructor() {}

  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }

  startMark(name: string): void {
    this.marks.set(name, performance.now());
    // @ts-ignore optional API
    if ((performance as any).mark) {
      (performance as any).mark(`${name}-start`);
    }
  }

  endMark(name: string): number | null {
    const startTime = this.marks.get(name);
    if (!startTime) {
      // eslint-disable-next-line no-console
      console.warn(`No start mark found for: ${name}`);
      return null;
    }

    const duration = performance.now() - startTime;
    this.marks.delete(name);

    // @ts-ignore optional API
    if ((performance as any).mark && (performance as any).measure) {
      (performance as any).mark(`${name}-end`);
      (performance as any).measure(name, `${name}-start`, `${name}-end`);
    }

    // eslint-disable-next-line no-console
    console.log(`⏱️ ${name}: ${duration.toFixed(2)}ms`);
    return duration;
  }

  logPageLoad(): void {
    const timing = (window.performance as any)?.timing;
    if (timing) {
      const loadTime = timing.loadEventEnd - timing.navigationStart;
      const domReadyTime = timing.domContentLoadedEventEnd - timing.navigationStart;
      const renderTime = timing.domComplete - timing.domLoading;

      // eslint-disable-next-line no-console
      console.log('📊 Performance Metrics:');
      // eslint-disable-next-line no-console
      console.log(`  Page Load: ${loadTime}ms`);
      // eslint-disable-next-line no-console
      console.log(`  DOM Ready: ${domReadyTime}ms`);
      // eslint-disable-next-line no-console
      console.log(`  Render: ${renderTime}ms`);
    }
  }

  getMemoryUsage(): string | null {
    // Chrome-only non-standard API
    const perfAny = performance as any;
    if ('memory' in perfAny) {
      const memory = perfAny.memory;
      const used = (memory.usedJSHeapSize / 1048576).toFixed(2);
      const total = (memory.totalJSHeapSize / 1048576).toFixed(2);
      return `${used}MB / ${total}MB`;
    }
    return null;
  }
}

export const perfMonitor = PerformanceMonitor.getInstance();
