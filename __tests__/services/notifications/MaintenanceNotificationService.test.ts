import { describe, it, expect, beforeEach, vi } from 'vitest';
import { MaintenanceNotificationService } from '@/services/notifications/MaintenanceNotificationService';

// vitest.setup.ts already defines global.Notification and fetch mocks if missing

describe('MaintenanceNotificationService', () => {
  let svc: MaintenanceNotificationService;

  beforeEach(() => {
    svc = new MaintenanceNotificationService();
    vi.restoreAllMocks();
    // Ensure env defaults
    delete (process as any).env.NEXT_PUBLIC_WEBHOOK_ENABLED;
    delete (process as any).env.NEXT_PUBLIC_MAINTENANCE_WEBHOOK;
  });

  it('sendBrowserNotification no-ops when not in browser', async () => {
    const origWin = (global as any).window;
    // Simulate Node environment without window/Notification
    // @ts-expect-error
    delete (global as any).window;
    // @ts-expect-error
    const originalNotification = (global as any).Notification;
    // @ts-expect-error
    delete (global as any).Notification;

    await svc.sendBrowserNotification({ title: 't', message: 'm' });

    // restore
    (global as any).window = origWin;
    (global as any).Notification = originalNotification;
    expect(true).toBe(true); // Reached without throwing
  });

  it('sendBrowserNotification shows notification when permission granted', async () => {
    const created: any[] = [];
    const orig = (global as any).Notification;
    // @ts-expect-error - test shim
    (global as any).Notification = {
      permission: 'granted',
      requestPermission: vi.fn(),
    };
    const NewNotif = vi.fn();
    // Create a proxy constructor to capture instantiation
    // @ts-expect-error
    (global as any).Notification = new Proxy((global as any).Notification, {
      construct: () => {
        created.push(true);
        return {} as any;
      },
      get: (t, p) => (t as any)[p],
    });

    await svc.sendBrowserNotification({ title: 'Hello', message: 'World' });

    expect(created.length).toBe(1);
    (global as any).Notification = orig;
  });

  it('sendBrowserNotification requests permission if not denied', async () => {
    const requested: any[] = [];
    const orig = (global as any).Notification;
    // @ts-expect-error - test shim
    (global as any).Notification = {
      permission: 'default',
      requestPermission: vi.fn().mockImplementation(async () => {
        requested.push(true);
        return 'granted';
      }),
    };
    // Capture creation when permission becomes granted
    const created: any[] = [];
    (global as any).Notification = new Proxy((global as any).Notification, {
      construct: () => {
        created.push(true);
        return {} as any;
      },
      get: (t, p) => (t as any)[p],
    });

    await svc.sendBrowserNotification({ title: 't' });

    expect(requested.length).toBe(1);
    expect(created.length).toBe(1);
    (global as any).Notification = orig;
  });

  it('sendWebhook no-ops when fetch undefined or URL missing', async () => {
    const origFetch = (global as any).fetch;
    // @ts-expect-error - simulate no fetch
    delete (global as any).fetch;

    await svc.sendWebhook({ title: 'x' });
    // Restore and ensure no crash
    (global as any).fetch = origFetch;

    // Missing URL
    (process as any).env.NEXT_PUBLIC_WEBHOOK_ENABLED = 'true';
    await svc.sendWebhook({ title: 'y' });

    expect(true).toBe(true);
  });

  it('sendWebhook posts expected payload when configured', async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true });
    (global as any).fetch = mockFetch;
    (process as any).env.NEXT_PUBLIC_WEBHOOK_ENABLED = 'true';
    (process as any).env.NEXT_PUBLIC_MAINTENANCE_WEBHOOK = 'https://example.test/webhook';

    const alert = {
      type: 'due_soon',
      severity: 'high',
      vehicleName: 'Truck 1',
      priority: 'critical',
      dueDate: new Date('2025-01-01T00:00:00Z'),
    } as const;

    await svc.sendWebhook(alert);

    expect(mockFetch).toHaveBeenCalledTimes(1);
    const [url, init] = mockFetch.mock.calls[0];
    expect(url).toBe('https://example.test/webhook');
    expect((init as any).method).toBe('POST');
    const body = JSON.parse((init as any).body);
    expect(body.text).toContain('due_soon');
    expect(body.attachments[0].color).toBe('danger');
    const fields = body.attachments[0].fields;
    expect(fields.find((f: any) => f.title === 'Vehicle')?.value).toBe('Truck 1');
  });

  it('notify triggers browser notification and webhook when enabled', async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true });
    (global as any).fetch = mockFetch;
    (process as any).env.NEXT_PUBLIC_WEBHOOK_ENABLED = 'true';
    (process as any).env.NEXT_PUBLIC_MAINTENANCE_WEBHOOK = 'https://example.test/webhook';

    // Set Notification granted
    const orig = (global as any).Notification;
    // @ts-expect-error - test shim
    (global as any).Notification = {
      permission: 'granted',
      requestPermission: vi.fn(),
    };
    let created = 0;
    (global as any).Notification = new Proxy((global as any).Notification, {
      construct: () => {
        created += 1;
        return {} as any;
      },
      get: (t, p) => (t as any)[p],
    });

    await svc.notify({ title: 'Maintenance', message: 'Check engine' });

    expect(created).toBe(1);
    expect(mockFetch).toHaveBeenCalledTimes(1);
    (global as any).Notification = orig;
  });

  it('notify skips webhook when disabled', async () => {
    const mockFetch = vi.fn();
    (global as any).fetch = mockFetch;
    await svc.notify({ title: 't' });
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it('handles errors in sendWebhook without throwing', async () => {
    (global as any).fetch = vi.fn().mockRejectedValue(new Error('netfail'));
    (process as any).env.NEXT_PUBLIC_WEBHOOK_ENABLED = 'true';
    (process as any).env.NEXT_PUBLIC_MAINTENANCE_WEBHOOK = 'https://example.test/webhook';
    await svc.sendWebhook({ title: 't' });
    expect(true).toBe(true);
  });

  it('handles errors in sendBrowserNotification without throwing', async () => {
    const orig = (global as any).Notification;
    // Force throwing when constructing Notification
    // @ts-expect-error - test shim
    (global as any).Notification = {
      permission: 'granted',
      requestPermission: vi.fn(),
    };
    (global as any).Notification = new Proxy((global as any).Notification, {
      construct: () => {
        throw new Error('boom');
      },
      get: (t, p) => (t as any)[p],
    });

    await svc.sendBrowserNotification({ title: 'x' });
    (global as any).Notification = orig;
    expect(true).toBe(true);
  });
});
