import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final unreadNotifications = ref.watch(unreadNotificationsProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            unreadCount.when(
              data: (count) => Text(
                '$count unread',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Mark all as read'),
                onTap: () async {
                  await ref.read(notificationServiceProvider).markAllAsRead();
                },
              ),
              PopupMenuItem(
                child: const Text('Clear read notifications'),
                onTap: () async {
                  await ref.read(notificationServiceProvider).clearReadNotifications();
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Toggle
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                const Text('Show unread only'),
                const Spacer(),
                Switch(
                  value: _showUnreadOnly,
                  onChanged: (value) => setState(() => _showUnreadOnly = value),
                ),
              ],
            ),
          ),

          // Notification List
          Expanded(
            child: _showUnreadOnly
                ? unreadNotifications.when(
                    data: (notifications) => _buildNotificationList(notifications),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  )
                : FutureBuilder(
                    future: ref.read(notificationServiceProvider).getNotifications(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final notifications = snapshot.data ?? [];
                      return _buildNotificationList(notifications);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No notifications', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(unreadNotificationsProvider);
        setState(() {});
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final icon = _getNotificationIcon(notification.type);
    final color = _getNotificationColor(notification.priority);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await ref.read(notificationServiceProvider).deleteNotification(notification.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification deleted')),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: notification.read ? null : color.withValues(alpha: 0.05),
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notification.read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.loadAssigned:
        return Icons.local_shipping;
      case NotificationType.loadUpdated:
        return Icons.update;
      case NotificationType.hosAlert:
        return Icons.schedule;
      case NotificationType.safetyEvent:
        return Icons.warning;
      case NotificationType.maintenanceAlert:
        return Icons.build;
      case NotificationType.geofenceEvent:
        return Icons.location_on;
      case NotificationType.emergencyAlert:
        return Icons.emergency;
      case NotificationType.messageReceived:
        return Icons.message;
      case NotificationType.settlementReady:
        return Icons.account_balance_wallet;
      case NotificationType.documentRequired:
        return Icons.description;
    }
  }

  Color _getNotificationColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.blue;
      case NotificationPriority.normal:
        return Colors.green;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.urgent:
        return Colors.red;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    // Mark as read
    if (!notification.read) {
      await ref.read(notificationServiceProvider).markAsRead(notification.id);
    }

    // Navigate based on notification type and data
    if (!mounted) return;

    switch (notification.type) {
      case NotificationType.loadAssigned:
      case NotificationType.loadUpdated:
        if (notification.data?['load_id'] != null) {
          Navigator.pushNamed(
            context,
            '/loads/details',
            arguments: notification.data!['load_id'],
          );
        }
        break;
      case NotificationType.hosAlert:
        Navigator.pushNamed(context, '/hos');
        break;
      case NotificationType.safetyEvent:
        Navigator.pushNamed(context, '/safety');
        break;
      case NotificationType.maintenanceAlert:
        Navigator.pushNamed(context, '/maintenance');
        break;
      case NotificationType.messageReceived:
        Navigator.pushNamed(context, '/messages');
        break;
      case NotificationType.settlementReady:
        Navigator.pushNamed(context, '/settlements');
        break;
      default:
        break;
    }
  }
}
