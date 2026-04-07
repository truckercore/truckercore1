/// Hours of Service related models
library;

enum DutyStatus { onDuty, offDuty, driving, sleeper }

enum MessagePriority { low, normal, high }

class HOSStatus {
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic>? details;

  HOSStatus({required this.status, required this.createdAt, this.details});

  factory HOSStatus.fromJson(Map<String, dynamic> json) => HOSStatus(
        status: json['status'] as String? ?? 'unknown',
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
        details: json['details'] is Map ? Map<String, dynamic>.from(json['details']) : null,
      );
}

class HOSViolation {
  final String id;
  final String type;
  final String description;
  final DateTime createdAt;

  HOSViolation({
    required this.id,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  factory HOSViolation.fromJson(Map<String, dynamic> json) => HOSViolation(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? 'unknown',
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}

class HOSTimeRemaining {
  final int driveMinutes;
  final int dutyMinutes;
  final int cycleMinutes;

  HOSTimeRemaining({
    required this.driveMinutes,
    required this.dutyMinutes,
    required this.cycleMinutes,
  });

  factory HOSTimeRemaining.fromJson(Map<String, dynamic> json) => HOSTimeRemaining(
        driveMinutes: (json['drive_minutes'] as num?)?.toInt() ?? 0,
        dutyMinutes: (json['duty_minutes'] as num?)?.toInt() ?? 0,
        cycleMinutes: (json['cycle_minutes'] as num?)?.toInt() ?? 0,
      );
}

class HOSAlert {
  final String id;
  final String type;
  final String message;
  final DateTime createdAt;

  HOSAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  factory HOSAlert.fromJson(Map<String, dynamic> json) => HOSAlert(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? 'hos',
        message: json['message'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}

class Message {
  final String id;
  final String recipientId;
  final String content;
  final String? attachmentUrl;
  final String? priority;
  final DateTime sentAt;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.recipientId,
    required this.content,
    this.attachmentUrl,
    this.priority,
    required this.sentAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id']?.toString() ?? '',
        recipientId: json['recipient_id']?.toString() ?? '',
        content: json['content'] as String? ?? '',
        attachmentUrl: json['attachment_url'] as String?,
        priority: json['priority'] as String?,
        sentAt: DateTime.parse(json['sent_at'] as String? ?? DateTime.now().toIso8601String()),
        readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      );
}

class LoadNotification {
  final String id;
  final String type;
  final String message;
  final bool acknowledged;
  final DateTime createdAt;

  LoadNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.acknowledged,
    required this.createdAt,
  });

  factory LoadNotification.fromJson(Map<String, dynamic> json) => LoadNotification(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? 'general',
        message: json['message'] as String? ?? '',
        acknowledged: json['acknowledged'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}
