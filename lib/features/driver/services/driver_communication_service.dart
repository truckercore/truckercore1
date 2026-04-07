import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/hos_models.dart';

final driverCommunicationServiceProvider = Provider<DriverCommunicationService>((ref) {
  return DriverCommunicationService();
});

class DriverCommunicationService {
  /// Send message to dispatcher
  Future<void> sendMessage({
    required String recipientId,
    required String content,
    String? attachmentUrl,
    MessagePriority priority = MessagePriority.normal,
  }) async {
    await SupaClient.from('messages').insert({
      'recipient_id': recipientId,
      'content': content,
      'attachment_url': attachmentUrl,
      'priority': priority.name,
      'sent_at': DateTime.now().toIso8601String(),
    });
  }

  /// Watch incoming messages
  Stream<List<Message>> watchMessages() {
    return SupaClient.stream(
      'messages',
      primaryKey: const ['id'],
      filter: (query) => query.order('sent_at', ascending: false),
    ).map((data) => data.map((m) => Message.fromJson(Map<String, dynamic>.from(m))).toList());
  }

  /// Mark message as read
  Future<void> markAsRead(String messageId) async {
    await SupaClient.from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);
  }

  /// Upload document (BOL, POD, inspection report)
  Future<String> uploadDocument({
    required String documentType,
    required String filePath,
    required String loadId,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await SupaClient.functions('upload-document', {
      'document_type': documentType,
      'file_path': filePath,
      'load_id': loadId,
      'metadata': metadata,
    });

    final map = Map<String, dynamic>.from(response.data as Map);
    return map['document_url'] as String;
  }

  /// Submit proof of delivery
  Future<void> submitProofOfDelivery({
    required String loadId,
    required String signatureUrl,
    required List<String> photoUrls,
    String? notes,
  }) async {
    await SupaClient.from('proof_of_delivery').insert({
      'load_id': loadId,
      'signature_url': signatureUrl,
      'photo_urls': photoUrls,
      'notes': notes,
      'submitted_at': DateTime.now().toIso8601String(),
    });
  }

  /// Watch load notifications
  Stream<LoadNotification> watchLoadNotifications() {
    return SupaClient.stream(
      'load_notifications',
      primaryKey: const ['id'],
      filter: (query) => query
          .eq('acknowledged', false)
          .order('created_at', ascending: false),
    ).map((data) => LoadNotification.fromJson(Map<String, dynamic>.from(data.first)));
  }

  /// Acknowledge load notification
  Future<void> acknowledgeNotification(String notificationId) async {
    await SupaClient.from('load_notifications')
        .update({'acknowledged': true, 'acknowledged_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId);
  }
}
