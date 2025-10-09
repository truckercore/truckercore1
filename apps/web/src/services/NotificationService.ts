import { EventEmitter } from 'events';

export enum NotificationType {
  INFO = 'info',
  SUCCESS = 'success',
  WARNING = 'warning',
  ERROR = 'error',
  ALERT = 'alert'
}

export enum NotificationPriority {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

export interface Notification {
  id: string;
  type: NotificationType;
  priority: NotificationPriority;
  title: string;
  message: string;
  timestamp: Date;
  read: boolean;
  actionUrl?: string;
  metadata?: Record<string, any>;
  expiresAt?: Date;
}

export interface NotificationPreferences {
  userId: string;
  emailEnabled: boolean;
  pushEnabled: boolean;
  smsEnabled: boolean;
  inAppEnabled: boolean;
  quietHoursStart?: string;
  quietHoursEnd?: string;
  priorityThreshold: NotificationPriority;
}

class NotificationService extends EventEmitter {
  private notifications: Map<string, Notification> = new Map();
  private preferences: Map<string, NotificationPreferences> = new Map();
  private maxNotifications = 1000;

  constructor() {
    super();
    this.startCleanupInterval();
  }

  async createNotification(
    userId: string,
    notification: Omit<Notification, 'id' | 'timestamp' | 'read'>
  ): Promise<Notification> {
    const newNotification: Notification = {
      ...notification,
      id: this.generateId(),
      timestamp: new Date(),
      read: false,
    };

    const prefs = this.preferences.get(userId);

    if (!this.shouldSendNotification(newNotification, prefs)) {
      return newNotification;
    }

    this.notifications.set(newNotification.id, newNotification);
    this.enforceLimit();

    this.emit('notification:created', userId, newNotification);

    await this.sendThroughChannels(userId, newNotification, prefs);

    return newNotification;
  }

  getNotifications(
    userId: string,
    filters?: {
      unreadOnly?: boolean;
      type?: NotificationType;
      priority?: NotificationPriority;
      limit?: number;
    }
  ): Notification[] {
    let notifications = Array.from(this.notifications.values());

    if (filters?.unreadOnly) {
      notifications = notifications.filter((n) => !n.read);
    }

    if (filters?.type) {
      notifications = notifications.filter((n) => n.type === filters.type);
    }

    if (filters?.priority) {
      notifications = notifications.filter((n) => n.priority === filters.priority);
    }

    notifications.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());

    if (filters?.limit) {
      notifications = notifications.slice(0, filters.limit);
    }

    return notifications;
  }

  markAsRead(notificationId: string): boolean {
    const notification = this.notifications.get(notificationId);
    if (notification) {
      notification.read = true;
      this.emit('notification:read', notificationId);
      return true;
    }
    return false;
  }

  markAllAsRead(userId: string): void {
    Array.from(this.notifications.values()).forEach((notification) => {
      notification.read = true;
    });
    this.emit('notification:all-read', userId);
  }

  deleteNotification(notificationId: string): boolean {
    const deleted = this.notifications.delete(notificationId);
    if (deleted) {
      this.emit('notification:deleted', notificationId);
    }
    return deleted;
  }

  getUnreadCount(userId: string): number {
    return this.getNotifications(userId, { unreadOnly: true }).length;
  }

  setPreferences(preferences: NotificationPreferences): void {
    this.preferences.set(preferences.userId, preferences);
  }

  getPreferences(userId: string): NotificationPreferences | undefined {
    return this.preferences.get(userId);
  }

  async sendAlert(
    userId: string,
    title: string,
    message: string,
    metadata?: Record<string, any>
  ): Promise<Notification> {
    return this.createNotification(userId, {
      type: NotificationType.ALERT,
      priority: NotificationPriority.CRITICAL,
      title,
      message,
      metadata,
    });
  }

  private shouldSendNotification(
    notification: Notification,
    prefs?: NotificationPreferences
  ): boolean {
    if (!prefs || !prefs.inAppEnabled) {
      return false;
    }

    const priorityOrder = {
      [NotificationPriority.LOW]: 0,
      [NotificationPriority.MEDIUM]: 1,
      [NotificationPriority.HIGH]: 2,
      [NotificationPriority.CRITICAL]: 3,
    } as const;

    if (priorityOrder[notification.priority] < priorityOrder[prefs.priorityThreshold]) {
      return false;
    }

    if (prefs.quietHoursStart && prefs.quietHoursEnd) {
      const now = new Date();
      const currentHour = now.getHours();
      const startHour = parseInt(prefs.quietHoursStart.split(':')[0]);
      const endHour = parseInt(prefs.quietHoursEnd.split(':')[0]);

      if (currentHour >= startHour || currentHour < endHour) {
        return notification.priority === NotificationPriority.CRITICAL;
      }
    }

    return true;
  }

  private async sendThroughChannels(
    userId: string,
    notification: Notification,
    prefs?: NotificationPreferences
  ): Promise<void> {
    if (!prefs) return;

    const promises: Promise<void>[] = [];

    if (prefs.emailEnabled) {
      promises.push(this.sendEmail(userId, notification));
    }

    if (prefs.pushEnabled) {
      promises.push(this.sendPush(userId, notification));
    }

    if (prefs.smsEnabled && notification.priority === NotificationPriority.CRITICAL) {
      promises.push(this.sendSMS(userId, notification));
    }

    await Promise.allSettled(promises);
  }

  private async sendEmail(userId: string, notification: Notification): Promise<void> {
    console.log(`Sending email notification to user ${userId}:`, notification.title);
  }

  private async sendPush(userId: string, notification: Notification): Promise<void> {
    console.log(`Sending push notification to user ${userId}:`, notification.title);
  }

  private async sendSMS(userId: string, notification: Notification): Promise<void> {
    console.log(`Sending SMS notification to user ${userId}:`, notification.title);
  }

  private generateId(): string {
    return `notif_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private enforceLimit(): void {
    if (this.notifications.size > this.maxNotifications) {
      const sorted = Array.from(this.notifications.entries()).sort(
        (a, b) => a[1].timestamp.getTime() - b[1].timestamp.getTime()
      );
      const toRemove = sorted.slice(0, this.notifications.size - this.maxNotifications);
      toRemove.forEach(([id]) => this.notifications.delete(id));
    }
  }

  private startCleanupInterval(): void {
    setInterval(() => {
      const now = new Date();
      Array.from(this.notifications.entries()).forEach(([id, notification]) => {
        if (notification.expiresAt && notification.expiresAt < now) {
          this.notifications.delete(id);
        }
      });
    }, 60000);
  }
}

export const notificationService = new NotificationService();
