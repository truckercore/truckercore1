import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/notification.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final unreadNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUnreadNotifications();
});

final unreadCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUnreadCount();
});

class NotificationService {
  StreamController<AppNotification>? _localNotificationController;

  /// Watch unread notifications
  Stream<List<AppNotification>> watchUnreadNotifications() {
    return SupaClient.stream(
      'notifications',
      primaryKey: const ['id'],
      filter: (query) => query.eq('read', false).order('created_at', ascending: false),
    ).map((data) => data.map((n) => AppNotification.fromJson(Map<String, dynamic>.from(n))).toList());
  }

  /// Watch unread notification count
  Stream<int> watchUnreadCount() {
    return watchUnreadNotifications().map((notifications) => notifications.length);
  }

  /// Get all notifications with pagination
  Future<List<AppNotification>> getNotifications({
    int limit = 50,
    int offset = 0,
    bool? readFilter,
  }) async {
    var query = SupaClient.from('notifications')
        .select('*')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (readFilter != null) {
      query = query.eq('read', readFilter);
    }

    final response = await query;
    return (response as List)
        .map((n) => AppNotification.fromJson(Map<String, dynamic>.from(n)))
        .toList();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await SupaClient.from('notifications').update({
      'read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await SupaClient.from('notifications').update({
      'read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('read', false);
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await SupaClient.from('notifications').delete().eq('id', notificationId);
  }

  /// Clear all read notifications
  Future<void> clearReadNotifications() async {
    await SupaClient.from('notifications').delete().eq('read', true);
  }

  /// Send notification (for testing or internal use)
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? data,
  }) async {
    await SupaClient.from('notifications').insert({
      'user_id': userId,
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'message': message,
      'data': data,
    });
  }

  /// Listen for real-time local notifications
  Stream<AppNotification> get localNotifications {
    _localNotificationController ??= StreamController<AppNotification>.broadcast();
    return _localNotificationController!.stream;
  }

  /// Emit local notification (for in-app alerts)
  void emitLocalNotification(AppNotification notification) {
    _localNotificationController?.add(notification);
  }

  /// Register device for push notifications
  Future<void> registerDevice(String deviceToken) async {
    await SupaClient.from('device_tokens').upsert({
      'token': deviceToken,
      'platform': _getPlatform(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Unregister device
  Future<void> unregisterDevice(String deviceToken) async {
    await SupaClient.from('device_tokens').delete().eq('token', deviceToken);
  }

  String _getPlatform() {
    // Determine platform
    return 'android'; // or 'ios', 'web'
  }

  void dispose() {
    _localNotificationController?.close();
  }
}
