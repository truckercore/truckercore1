// lib/core/connectivity/live_fallback_controller.dart
// Watches realtime heartbeat; if paused (>10s), switch to polling and show inline notice.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LiveMode { live, polling }

class LiveFallbackController extends StateNotifier<LiveMode> {
  LiveFallbackController() : super(LiveMode.live);

  Timer? _timer;
  DateTime? _lastHeartbeat;

  void recordHeartbeat() {
    _lastHeartbeat = DateTime.now();
    if (state == LiveMode.polling) state = LiveMode.live;
  }

  void startMonitoring({Duration threshold = const Duration(seconds: 10)}) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      final last = _lastHeartbeat;
      if (last == null) return; // no data yet
      final idle = DateTime.now().difference(last);
      if (idle > threshold && state != LiveMode.polling) {
        state = LiveMode.polling;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final liveFallbackProvider = StateNotifierProvider<LiveFallbackController, LiveMode>((ref) {
  final c = LiveFallbackController();
  c.startMonitoring();
  return c;
});
