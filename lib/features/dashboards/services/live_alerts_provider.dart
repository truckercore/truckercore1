import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class LiveAlertsState {
  final bool socketConnected;
  final int exceptionsCount;
  final DateTime lastUpdated;
  final bool pollingFallback;
  const LiveAlertsState({
    required this.socketConnected,
    required this.exceptionsCount,
    required this.lastUpdated,
    this.pollingFallback = false,
  });
  LiveAlertsState copyWith({
    bool? socketConnected,
    int? exceptionsCount,
    DateTime? lastUpdated,
    bool? pollingFallback,
  }) => LiveAlertsState(
    socketConnected: socketConnected ?? this.socketConnected,
    exceptionsCount: exceptionsCount ?? this.exceptionsCount,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    pollingFallback: pollingFallback ?? this.pollingFallback,
  );
}

class LiveAlertsController extends StateNotifier<LiveAlertsState> {
  LiveAlertsController(this._ref)
    : super(
        LiveAlertsState(
          socketConnected: false,
          exceptionsCount: 0,
          lastUpdated: DateTime.now(),
        ),
      );
  final Ref _ref;
  RealtimeChannel? _chan;
  Timer? _pollTimer;
  Timer? _debounce;

  void start({required String orgId}) {
    _subscribe(orgId);
    _startPolling(orgId);
  }

  void _subscribe(String orgId) {
    try {
      final cfg = _ref.read(appConfigProvider);
      final ready =
          cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
      if (!ready) return;
      _chan?.unsubscribe();
      _chan = Supabase.instance.client.channel('realtime:exceptions_$orgId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'exceptions',
          callback: (_) {
            _coalesceUpdate(state.exceptionsCount + 1);
          },
        )
        ..subscribe();
      state = state.copyWith(socketConnected: true, pollingFallback: false);
    } catch (_) {}
  }

  void _coalesceUpdate(int newCount) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(
        exceptionsCount: newCount,
        lastUpdated: DateTime.now(),
      );
    });
  }

  Future<int> _pollExceptions(String orgId) async {
    try {
      final cfg = _ref.read(appConfigProvider);
      final ready =
          cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
      if (!ready) return state.exceptionsCount;
      // Minimal polling: fetch a simple count via RPC if present; otherwise no-op.
      // Try a generic view 'v_exceptions_count' returning {count}
      final res = await Supabase.instance.client.rpc(
        'v_exceptions_count',
        params: {'p_org_id': orgId},
      );
      if (res is List && res.isNotEmpty) {
        final m = Map<String, dynamic>.from(res.first as Map);
        final cnt = (m['count'] as int?) ?? state.exceptionsCount;
        return cnt;
      }
      return state.exceptionsCount;
    } catch (_) {
      return state.exceptionsCount;
    }
  }

  void _startPolling(String orgId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (state.socketConnected == false) {
        // polling fallback active
        final cnt = await _pollExceptions(orgId);
        state = state.copyWith(
          exceptionsCount: cnt,
          pollingFallback: true,
          lastUpdated: DateTime.now(),
        );
      } else {
        state = state.copyWith(pollingFallback: false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pollTimer?.cancel();
    _chan?.unsubscribe();
    super.dispose();
  }
}

final liveAlertsProvider =
    StateNotifierProvider<LiveAlertsController, LiveAlertsState>((ref) {
      final ctrl = LiveAlertsController(ref);
      // Default org context in demo
      ctrl.start(orgId: 'demo_org');
      return ctrl;
    });
