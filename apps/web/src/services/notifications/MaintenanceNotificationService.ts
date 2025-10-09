export type MaintenanceAlert = {
  title?: string;
  message?: string;
  workOrderId?: string;
  vehicleId?: string;
  severity?: 'low' | 'medium' | 'high';
  type?: string;
  dueDate?: Date;
  priority?: string;
  vehicleName?: string;
};

export class MaintenanceNotificationService {
  async notify(alert: MaintenanceAlert) {
    await this.sendBrowserNotification(alert);

    if (process.env.NEXT_PUBLIC_WEBHOOK_ENABLED === 'true') {
      await this.sendWebhook(alert);
    }
  }

  // Made public for testing and integration
  async sendBrowserNotification(alert: MaintenanceAlert) {
    if (typeof window === 'undefined' || typeof Notification === 'undefined') return;

    const title = alert.title || 'Maintenance';
    const body = alert.message || '';

    try {
      if (Notification.permission === 'granted') {
        new Notification(title, { body });
      } else if (Notification.permission !== 'denied') {
        const perm = await Notification.requestPermission();
        if (perm === 'granted') {
          new Notification(title, { body });
        }
      }
    } catch (_) {
      // no-op
    }
  }

  // Made public for testing and integration
  async sendWebhook(alert: MaintenanceAlert) {
    if (typeof fetch === 'undefined') return;
    const url = process.env.NEXT_PUBLIC_MAINTENANCE_WEBHOOK;
    if (!url) return;
    try {
      const text = `Maintenance Alert: ${alert.type ?? alert.title ?? 'update'}`;
      const fields = [
        alert.vehicleName ? { title: 'Vehicle', value: alert.vehicleName } : undefined,
        alert.type ? { title: 'Type', value: String(alert.type) } : undefined,
        alert.priority ? { title: 'Priority', value: String(alert.priority) } : undefined,
        alert.dueDate ? { title: 'Due', value: new Date(alert.dueDate).toISOString() } : undefined,
      ].filter(Boolean);

      await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text,
          attachments: [
            {
              color: alert.severity === 'high' ? 'danger' : alert.severity === 'medium' ? 'warning' : 'good',
              fields,
            },
          ],
        }),
        keepalive: true,
      });
    } catch (_) {
      // swallow
    }
  }
}

export const maintenanceNotifier = new MaintenanceNotificationService();
