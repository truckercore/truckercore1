interface AnalyticsEvent {
  category: string;
  action: string;
  label?: string;
  value?: number;
}

class Analytics {
  private static instance: Analytics;
  private enabled: boolean = false;

  private constructor() {
    this.enabled = process.env.REACT_APP_ENABLE_ANALYTICS === 'true';
  }

  static getInstance(): Analytics {
    if (!Analytics.instance) {
      Analytics.instance = new Analytics();
    }
    return Analytics.instance;
  }

  trackPageView(path: string): void {
    if (!this.enabled) return;

    // eslint-disable-next-line no-console
    console.log('📈 Page View:', path);

    if (typeof window !== 'undefined' && (window as any).gtag) {
      (window as any).gtag('config', process.env.REACT_APP_GA_TRACKING_ID, {
        page_path: path,
      });
    }
  }

  trackEvent({ category, action, label, value }: AnalyticsEvent): void {
    if (!this.enabled) return;

    // eslint-disable-next-line no-console
    console.log('📊 Event:', { category, action, label, value });

    if (typeof window !== 'undefined' && (window as any).gtag) {
      (window as any).gtag('event', action, {
        event_category: category,
        event_label: label,
        value: value,
      });
    }
  }

  trackLoadAssignment(loadNumber: string, driverId: string): void {
    this.trackEvent({
      category: 'Dispatch',
      action: 'Load Assignment',
      label: `${loadNumber} -> ${driverId}`,
    });
  }

  trackExpenseSubmission(category: string, amount: number): void {
    this.trackEvent({
      category: 'Expense',
      action: 'Submission',
      label: category,
      value: amount,
    });
  }

  trackLoadPosting(rate: number, distance: number): void {
    this.trackEvent({
      category: 'Load',
      action: 'Posted',
      label: `$${rate} / ${distance}mi`,
      value: rate,
    });
  }

  trackPODCapture(loadNumber: string, photoCount: number): void {
    this.trackEvent({
      category: 'POD',
      action: 'Capture',
      label: loadNumber,
      value: photoCount,
    });
  }
}

export const analytics = Analytics.getInstance();
