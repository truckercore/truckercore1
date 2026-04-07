import { ipcMain, app } from 'electron';
import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';

interface AnalyticsConfig {
  mixpanelToken?: string;
  googleAnalyticsId?: string;
  customEndpoint?: string;
  enabled: boolean;
  userId?: string;
  userProperties?: Record<string, any>;
}

interface AnalyticsEvent {
  event: string;
  properties: Record<string, any>;
  timestamp: number;
  userId?: string;
  sessionId: string;
}

export class AnalyticsTracker {
  private config: AnalyticsConfig;
  private sessionId: string;
  private eventQueue: AnalyticsEvent[] = [];
  private flushInterval: NodeJS.Timeout | null = null;
  private analyticsFile: string;

  constructor(config: AnalyticsConfig) {
    this.config = config;
    this.sessionId = this.generateSessionId();
    this.analyticsFile = path.join(app.getPath('userData'), 'analytics.json');

    if (config.enabled) {
      this.setupHandlers();
      this.startFlushTimer();
      this.loadQueuedEvents();
    }
  }

  private setupHandlers() {
    ipcMain.handle('analytics:track', async (_event, eventName: string, properties: Record<string, any>) => {
      this.track(eventName, properties);
      return true;
    });

    ipcMain.handle('analytics:page-view', async (_event, pageName: string, properties: Record<string, any>) => {
      this.trackPageView(pageName, properties);
      return true;
    });

    ipcMain.handle('analytics:set-user', async (_event, userId: string, properties: Record<string, any>) => {
      this.setUser(userId, properties);
      return true;
    });

    ipcMain.handle('analytics:feature-used', async (_event, featureName: string, properties: Record<string, any>) => {
      this.trackFeatureUsage(featureName, properties);
      return true;
    });

    ipcMain.handle('analytics:track-error', async (_event, error: { name: string; message: string; stack?: string }, context: Record<string, any>) => {
      this.trackError(new Error(error?.message || 'Error'), { name: error?.name, stack: error?.stack, ...context });
      return true;
    });
  }

  track(eventName: string, properties: Record<string, any> = {}) {
    if (!this.config.enabled) return;

    const event: AnalyticsEvent = {
      event: eventName,
      properties: {
        ...properties,
        ...this.getDefaultProperties(),
      },
      timestamp: Date.now(),
      userId: this.config.userId,
      sessionId: this.sessionId,
    };

    this.eventQueue.push(event);
    // Persist small queues to disk to avoid loss on crash
    if (this.eventQueue.length >= 50) {
      this.saveQueuedEvents();
    }
  }

  trackPageView(pageName: string, properties: Record<string, any> = {}) {
    this.track('Page View', { page_name: pageName, ...properties });
  }

  setUser(userId: string, properties: Record<string, any> = {}) {
    this.config.userId = userId;
    this.config.userProperties = { ...(this.config.userProperties || {}), ...properties };
    this.track('User Identified', { user_id: userId, ...properties });
  }

  trackFeatureUsage(featureName: string, properties: Record<string, any> = {}) {
    this.track('Feature Used', { feature_name: featureName, ...properties });
  }

  trackError(error: Error, context: Record<string, any> = {}) {
    this.track('Error Occurred', {
      error_name: error.name,
      error_message: error.message,
      error_stack: (error as any)?.stack,
      ...context,
    });
  }

  private async flush(): Promise<void> {
    if (this.eventQueue.length === 0) return;

    const eventsToSend = [...this.eventQueue];
    this.eventQueue = [];

    try {
      if (this.config.mixpanelToken) {
        await this.sendToMixpanel(eventsToSend);
      }
      if (this.config.googleAnalyticsId) {
        await this.sendToGoogleAnalytics(eventsToSend);
      }
      if (this.config.customEndpoint) {
        await this.sendToCustomEndpoint(eventsToSend);
      }
      // on success, clear persisted file
      this.saveQueuedEvents();
      // eslint-disable-next-line no-console
      console.log(`[Analytics] Flushed ${eventsToSend.length} events`);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('[Analytics] Failed to flush events:', error);
      // Re-queue and persist for later
      this.eventQueue.unshift(...eventsToSend);
      this.saveQueuedEvents();
    }
  }

  private async sendToMixpanel(events: AnalyticsEvent[]): Promise<void> {
    const mixpanelEvents = events.map((e) => ({
      event: e.event,
      properties: {
        ...e.properties,
        token: this.config.mixpanelToken,
        distinct_id: e.userId || 'anonymous',
        time: Math.floor(e.timestamp / 1000),
      },
    }));
    // Mixpanel /track endpoint accepts JSON list when Content-Type is application/json
    await axios.post('https://api.mixpanel.com/track', mixpanelEvents, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000,
    });
  }

  private async sendToGoogleAnalytics(events: AnalyticsEvent[]): Promise<void> {
    // Google Analytics 4 Measurement Protocol requires api_secret; allow via env GA_API_SECRET if present
    const apiSecret = process.env.GA_API_SECRET;
    if (!apiSecret) return; // skip if not configured
    for (const event of events) {
      await axios.post(
        `https://www.google-analytics.com/mp/collect?measurement_id=${this.config.googleAnalyticsId}&api_secret=${apiSecret}`,
        {
          client_id: event.sessionId,
          events: [
            {
              name: event.event.toLowerCase().replace(/\s+/g, '_'),
              params: event.properties,
            },
          ],
        },
        { timeout: 10000 }
      );
    }
  }

  private async sendToCustomEndpoint(events: AnalyticsEvent[]): Promise<void> {
    await axios.post(
      this.config.customEndpoint!,
      { events, session_id: this.sessionId, user_id: this.config.userId },
      { timeout: 10000 }
    );
  }

  private getDefaultProperties(): Record<string, any> {
    return {
      app_version: app.getVersion(),
      platform: process.platform,
      arch: process.arch,
      session_id: this.sessionId,
      ...(this.config.userProperties || {}),
    };
  }

  private generateSessionId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  private startFlushTimer(): void {
    this.flushInterval = setInterval(() => {
      void this.flush();
    }, 30000);
  }

  private stopFlushTimer(): void {
    if (this.flushInterval) {
      clearInterval(this.flushInterval);
      this.flushInterval = null;
    }
  }

  private saveQueuedEvents(): void {
    try {
      fs.writeFileSync(this.analyticsFile, JSON.stringify(this.eventQueue, null, 2));
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('[Analytics] Failed to save queued events:', error);
    }
  }

  private loadQueuedEvents(): void {
    try {
      if (fs.existsSync(this.analyticsFile)) {
        const data = fs.readFileSync(this.analyticsFile, 'utf8');
        const parsed = JSON.parse(data);
        if (Array.isArray(parsed)) {
          this.eventQueue = parsed as AnalyticsEvent[];
          // eslint-disable-next-line no-console
          console.log(`[Analytics] Loaded ${this.eventQueue.length} queued events`);
        }
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('[Analytics] Failed to load queued events:', error);
    }
  }

  async shutdown(): Promise<void> {
    this.stopFlushTimer();
    await this.flush();
    this.saveQueuedEvents();
  }
}
