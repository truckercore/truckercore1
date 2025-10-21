// lib/core/realtime/realtime_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal realtime watchdog that can be extended to observe Supabase channels.
/// For now, we expose a status that allows UI to show a fallback polling banner.

enum LiveStatus { live, polling }

class RealtimeService extends StateNotifier<LiveStatus> {
  RealtimeService(): super(LiveStatus.live);

  // Call when channel disconnect is detected
  void pauseLive() => state = LiveStatus.polling;
  // Call when live resumes
  void resumeLive() => state = LiveStatus.live;
}

final realtimeStatusProvider = StateNotifierProvider<RealtimeService, LiveStatus>((ref){
  return RealtimeService();
});
