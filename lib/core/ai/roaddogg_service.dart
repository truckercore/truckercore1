import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/config/app_config.dart';
import '../../services/supa_client.dart';

class RoaddoggAnswer {
  final String requestId;
  final String text;
  final DateTime ts;
  const RoaddoggAnswer({required this.requestId, required this.text, required this.ts});
}

class RoaddoggService {
  final AppConfig config;
  final SupaClient? http; // null in mock
  RoaddoggService({required this.config, this.http});

  Future<RoaddoggAnswer> ask({
    required String role,
    required String planTier, // free|pro|premium
    required String intent,
    required Map<String, dynamic> context,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (config.useMockData || http == null) {
      // deterministic canned
      final txt = '[Mock][$role][$intent] For ${context['route'] ?? 'current'} → answer ready.';
      return RoaddoggAnswer(requestId: 'mock-req', text: txt, ts: DateTime.now());
    }
    try {
      final body = {
        'role': role,
        'plan': planTier,
        'intent': intent,
        'context': context,
      };
      final res = await http!.postJson('/functions/v1/roaddogg/ask', body, timeout: timeout);
      final requestId = (res['requestId'] ?? res['request_id'] ?? '') as String? ?? '';
      final text = (res['text'] ?? res['answer'] ?? 'No answer').toString();
      return RoaddoggAnswer(requestId: requestId, text: text, ts: DateTime.now());
    } on AppError catch (e) {
      return RoaddoggAnswer(requestId: 'error', text: 'RoadDogg error: ${e.message}', ts: DateTime.now());
    } catch (e) {
      return RoaddoggAnswer(requestId: 'error', text: 'RoadDogg failed: $e', ts: DateTime.now());
    }
  }
}

final roaddoggServiceProvider = Provider<RoaddoggService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (cfg.useMockData || cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) {
    return RoaddoggService(config: cfg);
  }
  final http = SupaClient(supabaseUrl: cfg.supabaseUrl, anonKey: cfg.supabaseAnonKey);
  return RoaddoggService(config: cfg, http: http);
});
