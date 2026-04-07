import 'dart:async';
import '../services/supa_client.dart';

class ChatMessage {
  final String id, loadId, senderRole;
  final String? senderId, text, attachmentPath;
  final DateTime createdAt;
  ChatMessage({
    required this.id,
    required this.loadId,
    required this.senderRole,
    this.senderId,
    this.text,
    this.attachmentPath,
    required this.createdAt,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    loadId: j['load_id'] as String,
    senderRole: j['sender_role'] as String,
    senderId: j['sender_id'] as String?,
    text: j['text'] as String?,
    attachmentPath: j['attachment_path'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

class ChatService {
  final SupaClient client;
  ChatService(this.client);

  Future<List<ChatMessage>> history(String loadId, {int limit = 100}) async {
    final res = await client.getJson(
      '/rest/v1/load_messages?select=*&load_id=eq.$loadId&order=created_at.asc&limit=$limit',
    );
    final data = (res['data'] ?? res) as List;
    return data
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> send(
    String loadId,
    String role, {
    String? text,
    String? attachmentPath,
  }) {
    return client
        .postJson('/rest/v1/load_messages', {
          'load_id': loadId,
          'sender_role': role,
          'text': text,
          'attachment_path': attachmentPath,
        })
        .then((_) {});
  }
}

/*
Realtime usage example (in a Widget):

final supa = Supabase.instance.client;
final channel = supa.channel('load-chat:LOAD_ID').onPostgresChanges(
  event: PostgresChangeEvent.insert,
  schema: 'public',
  table: 'load_messages',
  filter: PostgresChangeFilter('load_id', '=', 'LOAD_ID'),
  callback: (payload) { /* append and scroll */ },
).subscribe();
*/
