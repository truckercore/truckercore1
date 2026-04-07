// lib/core/refresh/refresh_orchestrator.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/connectivity/connectivity_provider.dart';
import '../config/refresh_intervals.dart';

/// App lifecycle provider so services can pause when app in background
final appLifecycleStateProvider = StateProvider<AppLifecycleState>((_) => AppLifecycleState.resumed);

/// Global flag to dedupe refreshes across the app
final refreshBusy = StateProvider<bool>((_) => false);

/// A lightweight orchestrator that emits refresh ticks with jitter and
/// pauses when the app is not in foreground. It also avoids polling while
/// offline and triggers an immediate refresh once back online.
class RefreshOrchestrator {
  RefreshOrchestrator(this.ref);
  final Ref ref;

  Timer? _poll;
  int _failCount = 0;

  Stream<DateTime> marketplaceTicks() => _ticks(
        base: RefreshIntervals.marketplace,
        jitter: RefreshIntervals.marketplaceJitter,
      );

  Stream<DateTime> fleetKpiTicks() => _ticks(
        base: RefreshIntervals.fleetKpis,
        jitter: RefreshIntervals.fleetKpisJitter,
      );

  Stream<DateTime> _ticks({required Duration base, required Duration jitter}) async* {
    DateTime? lastEmitted;
    // Start with cache-first pattern: emit once immediately (consumer can show cache)
    yield DateTime.now();
    final connectivity = ref.read(connectivityStatusProvider);
    var wasOnline = connectivity;
    while (true) {
      // Pause while app is not active
      while (ref.read(appLifecycleStateProvider) != AppLifecycleState.resumed) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      // If offline, wait and re-check until back online
      if (!ref.read(connectivityStatusProvider)) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      // Jittered delay
      final delay = RefreshIntervals.withJitter(base, jitter);
      await Future.delayed(delay);

      // If we just came back online, fire immediately (SWR revalidate)
      final onlineNow = ref.read(connectivityStatusProvider);
      if (!wasOnline && onlineNow) {
        wasOnline = true;
        final now = DateTime.now();
        if (lastEmitted == null || now.difference(lastEmitted).inSeconds >= 1) {
          lastEmitted = now;
          yield now;
          continue;
        }
      }
      wasOnline = onlineNow;

      final now = DateTime.now();
      lastEmitted = now;
      yield now;
    }
  }

  /// Deduplicated scoped refresh with exponential backoff on failures
  Future<void> refreshScoped(Future<void> Function() fn) async {
    if (ref.read(refreshBusy)) return; // dedupe
    ref.read(refreshBusy.notifier).state = true;
    try {
      await fn();
      _failCount = 0;
    } catch (_) {
      _failCount++;
      rethrow;
    } finally {
      ref.read(refreshBusy.notifier).state = false;
    }
  }

  /// Start periodic polling with backoff + jitter, used when live updates stall
  void onLiveStall() {
    _poll ??= Timer.periodic(_intervalWithBackoff(), (_) async {
      if (ref.read(appLifecycleStateProvider) != AppLifecycleState.resumed) return;
      if (!ref.read(connectivityStatusProvider)) return;
      // Add small scope refreshes here, example for fleet attention
      try {
        await refreshScoped(() async {
          // Call small, scoped refreshes only
          // Add calls to specific notifiers as needed
        });
      } catch (_) {}
    });
  }

  void onLiveResume() {
    _poll?.cancel();
    _poll = null;
    _failCount = 0;
  }

  Duration _intervalWithBackoff() {
    // base 30s, exp backoff capped ~5m, ±10% jitter
    final baseSeconds = 30 * (1 << _failCount).clamp(1, 10);
    final base = Duration(seconds: baseSeconds);
    final j = (base.inMilliseconds * 0.1).round();
    final nowMs = DateTime.now().millisecond;
    final delta = (nowMs % (j * 2)) - j; // [-j, +j]
    return Duration(milliseconds: base.inMilliseconds + delta);
  }
}

final refreshOrchestratorProvider = Provider<RefreshOrchestrator>((ref) => RefreshOrchestrator(ref));
