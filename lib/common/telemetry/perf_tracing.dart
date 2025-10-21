// lib/common/telemetry/perf_tracing.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// Lightweight perf span model
class PerfSpan {
  final String traceId;
  final String action;
  final DateTime startedAt;
  int? durationMs;
  String? cache; // 'HIT' | 'MISS' | null
  PerfSpan({required this.traceId, required this.action, required this.startedAt});
}

String _randId() {
  final r = Random();
  final bytes = List<int>.generate(12, (_) => r.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Budgets for badges (ms)
const _budgets = <String, Map<String, int>>{
  // p50 < 1.0s for search
  'loads.search': {'p50': 1000, 'p95': 3000},
  // ranker p95 < 1.5s
  'ranker.search': {'p50': 800, 'p95': 1500},
  // suggestion revalidate p95 < 3.0s
  'suggestions.revalidate': {'p50': 1200, 'p95': 3000},
  // generic writes
  'requests.create': {'p50': 1200, 'p95': 2500},
};

class _ActionWindow {
  final List<({DateTime t, int durMs, String? cache})> _events = [];
  void add(int durMs, {String? cache}) {
    final now = DateTime.now().toUtc();
    _events.add((t: now, durMs: durMs, cache: cache));
    // keep up to 200 recent
    if (_events.length > 200) {
      _events.removeRange(0, _events.length - 200);
    }
  }

  ({double p50, double p95, ({int ms, String? cache})? last}) stats({Duration horizon = const Duration(minutes: 10)}) {
    final now = DateTime.now().toUtc();
    final recent = _events.where((e) => now.difference(e.t) <= horizon).toList();
    if (recent.isEmpty) return (p50: 0, p95: 0, last: null);
    final sorted = [...recent]..sort((a, b) => a.durMs.compareTo(b.durMs));
    double pct(double p) {
      final idx = (p * (sorted.length - 1)).clamp(0, sorted.length - 1).toInt();
      return sorted[idx].durMs.toDouble();
    }
    final lastEv = recent.last;
    return (
      p50: pct(0.50),
      p95: pct(0.95),
      last: (ms: lastEv.durMs, cache: lastEv.cache),
    );
  }

  bool degraded(String action) {
    final b = _budgets[action];
    if (b == null) return false;
    final threshold = b['p95']!;
    // consider degraded if >20% of recent spans exceed p95 budget
    final now = DateTime.now().toUtc();
    final recent = _events.where((e) => now.difference(e.t) <= const Duration(minutes: 5)).toList();
    if (recent.length < 5) return false;
    final breaches = recent.where((e) => e.durMs > threshold).length;
    return breaches / recent.length > 0.20;
  }
}

/// Singleton tracer with Riverpod facade
class PerfTracer {
  static final PerfTracer instance = PerfTracer._internal();
  PerfTracer._internal();

  final _byAction = <String, _ActionWindow>{};
  final _controller = StreamController<void>.broadcast();

  PerfSpan startSpan(String action) {
    return PerfSpan(traceId: _randId(), action: action, startedAt: DateTime.now().toUtc());
  }

  Future<void> endSpan(PerfSpan span, {required bool ok, Map<String, Object?> extra = const {}, WidgetRef? ref}) async {
    final ended = DateTime.now().toUtc();
    final dur = ended.difference(span.startedAt).inMilliseconds;
    span.durationMs = dur;

    // rolling stats
    final win = _byAction.putIfAbsent(span.action, () => _ActionWindow());
    win.add(dur, cache: span.cache);
    _controller.add(null);

    // Debug log & analytics micro event (no PII)
    if (kDebugMode) {
      // ignore: avoid_print
      print('[perf.span] action=${span.action} durMs=$dur trace=${span.traceId} cache=${span.cache ?? '-'} ok=$ok');
    }

    // Fire-and-forget RPC record (ignore failures)
    Future.microtask(() async {
      try {
        final client = Supabase.instance.client;
        // Try to pull org_id/user_id from state if ref provided
        String? userId;
        try {
          userId = Supabase.instance.client.auth.currentUser?.id;
        } catch (_) {}
        await client.rpc('rpc_log_telemetry', params: {
          'p_kind': 'perf.span',
          'p_payload': {
            'trace_id': span.traceId,
            'action': span.action,
            'duration_ms': dur,
            'user_id': userId,
            'cache': span.cache,
          }
        });
      } catch (_) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[perf.span] record_trace failed (ignored)');
        }
      }
    });
  }

  Map<String, ({double p50, double p95, ({int ms, String? cache})? last})> getAllStats() {
    return _byAction.map((k, v) => MapEntry(k, v.stats()));
  }

  ({double p50, double p95, ({int ms, String? cache})? last}) statsFor(String action) {
    return _byAction[action]?.stats() ?? (p50: 0, p95: 0, last: null);
  }

  bool degradedFor(String action) => _byAction[action]?.degraded(action) ?? false;

  Stream<void> get changes => _controller.stream;
}

/// Providers for UI to observe perf state
final perfStatsProvider = StreamProvider.autoDispose<Map<String, ({double p50, double p95, ({int ms, String? cache})? last})>>((ref) {
  final tracer = PerfTracer.instance;
  final sub = tracer.changes.listen((_) {});
  ref.onDispose(() => sub.cancel());
  return Stream.periodic(const Duration(milliseconds: 500), (_) => tracer.getAllStats());
});

final perfDegradedProvider = Provider.family<bool, String>((ref, action) {
  return PerfTracer.instance.degradedFor(action);
});

/// Build standard headers for a request given the span/action.
Map<String, String> buildPerfHeaders(PerfSpan span) => {
  'X-Trace-Id': span.traceId,
  'X-RoadDogg-Action': span.action,
};

extension FunctionsTracing on FunctionsClient {
  /// Convenience wrapper to invoke with tracing headers.
  Future<dynamic> invokeWithTrace(
    String functionName, {
    required String action,
    PerfSpan? span,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final s = span ?? PerfTracer.instance.startSpan(action);
    try {
      final h = {
        ...buildPerfHeaders(s),
        if (headers != null) ...headers,
      };
      final res = await invoke(functionName, body: body, headers: h);
      // Attempt to read cache header is not supported by current SDK; skip.
      await PerfTracer.instance.endSpan(s, ok: true, extra: {});
      return res;
    } catch (e) {
      await PerfTracer.instance.endSpan(s, ok: false, extra: {'error': e.toString()});
      rethrow;
    }
  }
}
