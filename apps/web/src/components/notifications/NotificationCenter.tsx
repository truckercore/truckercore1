import React, { useEffect, useState } from 'react';
import {
  notificationService,
  Notification,
  NotificationType,
  NotificationPriority,
} from '../../services/NotificationService';

interface NotificationCenterProps {
  userId: string;
}

export const NotificationCenter: React.FC<NotificationCenterProps> = ({ userId }) => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [filter, setFilter] = useState<'all' | 'unread'>('all');
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    loadNotifications();

    const handleNew = (uid: string, n: Notification) => {
      if (uid === userId) {
        loadNotifications();
        showToast(n);
      }
    };

    const handleSimple = () => loadNotifications();

    notificationService.on('notification:created', handleNew);
    notificationService.on('notification:read', handleSimple);
    notificationService.on('notification:deleted', handleSimple);

    return () => {
      notificationService.off('notification:created', handleNew);
      notificationService.off('notification:read', handleSimple);
      notificationService.off('notification:deleted', handleSimple);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId, filter]);

  const loadNotifications = () => {
    const filters = filter === 'unread' ? { unreadOnly: true } : {};
    const list = notificationService.getNotifications(userId, filters);
    setNotifications(list);
    setUnreadCount(notificationService.getUnreadCount(userId));
  };

  const showToast = (notification: Notification) => {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      if (Notification.permission === 'granted') {
        new Notification(notification.title, {
          body: notification.message,
          icon: undefined,
          tag: notification.id,
        });
      } else if (Notification.permission !== 'denied') {
        Notification.requestPermission();
      }
    }
  };

  const handleMarkAsRead = (id: string) => notificationService.markAsRead(id);
  const handleMarkAllAsRead = () => notificationService.markAllAsRead(userId);
  const handleDelete = (id: string) => notificationService.deleteNotification(id);

  const getNotificationIcon = (type: NotificationType): string => {
    const icons: Record<NotificationType, string> = {
      [NotificationType.INFO]: '💡',
      [NotificationType.SUCCESS]: '✅',
      [NotificationType.WARNING]: '⚠️',
      [NotificationType.ERROR]: '❌',
      [NotificationType.ALERT]: '🚨',
    };
    return icons[type];
  };

  const getPriorityColor = (priority: NotificationPriority): string => {
    const colors: Record<NotificationPriority, string> = {
      [NotificationPriority.LOW]: 'bg-gray-100 text-gray-800',
      [NotificationPriority.MEDIUM]: 'bg-blue-100 text-blue-800',
      [NotificationPriority.HIGH]: 'bg-orange-100 text-orange-800',
      [NotificationPriority.CRITICAL]: 'bg-red-100 text-red-800',
    };
    return colors[priority];
  };

  const formatTimestamp = (date: Date): string => {
    const d = new Date(date);
    const now = new Date();
    const diff = now.getTime() - d.getTime();
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes}m ago`;
    if (hours < 24) return `${hours}h ago`;
    return `${days}d ago`;
  };

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="relative p-2 text-gray-600 hover:text-gray-900 focus:outline-none"
        aria-label="Notifications"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
        </svg>
        {unreadCount > 0 && (
          <span className="absolute top-0 right-0 inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-white transform translate-x-1/2 -translate-y-1/2 bg-red-600 rounded-full">
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>
        )}
      </button>

      {isOpen && (
        <div className="absolute right-0 mt-2 w-96 bg-white rounded-lg shadow-xl z-50 max-h-[600px] flex flex-col">
          <div className="p-4 border-b border-gray-200">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-lg font-semibold text-gray-900">Notifications</h3>
              <button onClick={() => setIsOpen(false)} className="text-gray-400 hover:text-gray-600" aria-label="Close">
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                </svg>
              </button>
            </div>

            <div className="flex gap-2">
              <button
                onClick={() => setFilter('all')}
                className={`px-3 py-1 rounded-md text-sm font-medium ${
                  filter === 'all' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                All
              </button>
              <button
                onClick={() => setFilter('unread')}
                className={`px-3 py-1 rounded-md text-sm font-medium ${
                  filter === 'unread' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                Unread ({unreadCount})
              </button>
              {unreadCount > 0 && (
                <button onClick={handleMarkAllAsRead} className="ml-auto px-3 py-1 rounded-md text-sm font-medium text-blue-600 hover:bg-blue-50">
                  Mark all read
                </button>
              )}
            </div>
          </div>

          <div className="flex-1 overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="p-8 text-center text-gray-500">
                <svg className="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                </svg>
                <p>No notifications</p>
              </div>
            ) : (
              <ul className="divide-y divide-gray-200">
                {notifications.map((n) => (
                  <li key={n.id} className={`p-4 hover:bg-gray-50 transition-colors ${!n.read ? 'bg-blue-50' : ''}`}>
                    <div className="flex items-start gap-3">
                      <span className="text-2xl flex-shrink-0">{getNotificationIcon(n.type)}</span>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between gap-2 mb-1">
                          <h4 className="text-sm font-semibold text-gray-900">{n.title}</h4>
                          <span className={`px-2 py-1 text-xs font-medium rounded ${getPriorityColor(n.priority)}`}>
                            {n.priority}
                          </span>
                        </div>
                        <p className="text-sm text-gray-600 mb-2">{n.message}</p>
                        <div className="flex items-center justify-between">
                          <span className="text-xs text-gray-400">{formatTimestamp(n.timestamp)}</span>
                          <div className="flex gap-2">
                            {!n.read && (
                              <button onClick={() => handleMarkAsRead(n.id)} className="text-xs text-blue-600 hover:text-blue-800">
                                Mark read
                              </button>
                            )}
                            <button onClick={() => handleDelete(n.id)} className="text-xs text-red-600 hover:text-red-800">
                              Delete
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
