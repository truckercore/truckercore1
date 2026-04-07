enum NotificationType {
  loadAssigned,
  loadUpdated,
  hosAlert,
  safetyEvent,
  maintenanceAlert,
  geofenceEvent,
  emergencyAlert,
  messageReceived,
  settlementReady,
  documentRequired,
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final NotificationPriority priority;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.message,
    this.data,
    this.read = false,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: NotificationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => NotificationType.messageReceived,
        ),
        priority: NotificationPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => NotificationPriority.normal,
        ),
        title: json['title'] as String,
        message: json['message'] as String,
        data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
        read: json['read'] as bool? ?? false,
        readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
