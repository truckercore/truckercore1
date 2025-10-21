// lib/features/tracking/tracking_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/config/app_config.dart';
import '../../common/services/event_logger.dart';
import 'offline_queue.dart';

enum TrackingState { idle, running, paused }

class GpsPoint {
  final String deviceId;
  final int seq;
  final DateTime ts;
  final double lat;
  final double lng;
  final double? speedMps;
  final String activity; // driving|idle|unknown
  const GpsPoint({
    required this.deviceId,
    required this.seq,
    required this.ts,
    required this.lat,
    required this.lng,
    this.speedMps,
    this.activity = 'unknown',
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'seq': seq,
        'ts': ts.toUtc().toIso8601String(),
        'lat': lat,
        'lng': lng,
        if (speedMps != null) 'speed': speedMps,
        'activity': activity,
      };
}

class TrackingController extends StateNotifier<TrackingState> {
  TrackingController(this._ref)
      : _deviceId = Supabase.instance.client.auth.currentUser?.id ?? _randomId(),
        super(TrackingState.idle);

  final Ref _ref;
  final String _deviceId;
  Timer? _timer;
  int _seq = 0;
  bool _uploading = false;
  bool _inited = false;
  final OfflineQueue _queue = SharedPrefsQueue();
  final SeqStore _seqStore = SeqStore();

  static String _randomId() {
    final r = Random();
    return 'dev_${r.nextInt(1 << 32)}';
  }

  Future<void> start() async {
    if (state == TrackingState.running) return;
    await _ensureInit();
    state = TrackingState.running;
    _ref.read(_eventLoggerProvider).log('tracking_state', {
      'state': 'start',
    });
    // Attempt to flush any pending points immediately
    unawaited(_uploadBuffer());
    _scheduleNextTick(immediate: true);
  }

  void pause() {
    if (state != TrackingState.running) return;
    state = TrackingState.paused;
    _timer?.cancel();
    _ref.read(_eventLoggerProvider).log('tracking_state', {
      'state': 'pause',
    });
  }

  void resume() {
    if (state != TrackingState.paused) return;
    state = TrackingState.running;
    _ref.read(_eventLoggerProvider).log('tracking_state', {
      'state': 'resume',
    });
    _scheduleNextTick();
  }

  void stop() {
    state = TrackingState.idle;
    _timer?.cancel();
    _ref.read(_eventLoggerProvider).log('tracking_state', {
      'state': 'stop',
    });
  }

  Duration _cadenceFor(double speedMps) {
    // ~10–30s while driving (>5 m/s ~ 11 mph), 2–5 min when idle
    if (speedMps > 5.0) {
      return const Duration(seconds: 15);
    }
    return const Duration(minutes: 3);
  }

  Future<void> _ensureInit() async {
    if (_inited) return;
    await _queue.init();
    try {
      _seq = await _seqStore.read(_deviceId);
    } catch (_) {/* default 0 */}
    _inited = true;
  }

  Future<void> _tick() async {
    if (state != TrackingState.running) return;
    // Try to obtain a position. If permissions missing, skip silently.
    double? lat;
    double? lng;
    double? speed;
    try {
      final hasPerm = await Geolocator.checkPermission();
      if (hasPerm == LocationPermission.denied || hasPerm == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
      speed = pos.speed;
    } catch (_) {
      // In tests/desktop, geolocator may be unavailable — no-op
    }
    if (lat == null || lng == null) {
      _scheduleNextTick();
      return;
    }
    final activity = (speed ?? 0) > 5.0 ? 'driving' : 'idle';
    final point = GpsPoint(
      deviceId: _deviceId,
      seq: ++_seq,
      ts: DateTime.now().toUtc(),
      lat: lat,
      lng: lng,
      speedMps: speed,
      activity: activity,
    );
    // Enqueue durably and persist seq
    try {
      await _queue.enqueue(point);
      await _seqStore.write(_deviceId, _seq);
    } catch (_) {/* best-effort persistence */}
    // Fire-and-forget upload
    unawaited(_uploadBuffer());
    _scheduleNextTick(lastSpeedMps: speed ?? 0);
  }

  void _scheduleNextTick({bool immediate = false, double lastSpeedMps = 0}) {
    _timer?.cancel();
    if (state != TrackingState.running) return;
    final delay = immediate ? Duration.zero : _cadenceFor(lastSpeedMps);
    _timer = Timer(delay, _tick);
  }

  Future<void> _uploadBuffer() async {
    if (_uploading) return;
    final pendingSize = await _queue.size();
    if (pendingSize == 0) return;
    _uploading = true;
    try {
      final cfg = _ref.read(appConfigProvider);
      final client = Supabase.instance.client;
      // Prefer backend ingest endpoint if configured; else use an Edge Function name
      final url = cfg.backend.isNotEmpty ? Uri.parse('${cfg.backend.replaceAll(RegExp(r'/+$'),'')}/ingest') : null;
      final points = await _queue.peek(100); // chunk
      if (points.isEmpty) return;
      final body = points.map((e) => e.toJson()).toList();
      final idem = 'track_${_deviceId}_${points.first.seq}_${points.last.seq}';
      bool ok = false;
      if (url != null) {
        try {
          // Note: for simplicity, we continue to use Edge Function path unless a proper HTTP client is wired.
        } catch (_) {}
      }
      if (!ok) {
        // Edge Function fallback (must be deployed): 'ingest_tracking'
        try {
          final resp = await client.functions.invoke('ingest_tracking',
              body: { 'points': body }, headers: { 'idempotency-key': idem });
          ok = (resp.data is Map) ? (resp.data['ok'] == true) : true;
        } catch (_) {/* ignore */}
      }
      if (ok) {
        await _queue.removeThroughSeq(_deviceId, points.last.seq);
      }
    } finally {
      _uploading = false;
    }
  }
}

final trackingControllerProvider = StateNotifierProvider<TrackingController, TrackingState>((ref) {
  return TrackingController(ref);
});

final _eventLoggerProvider = Provider<EventLogger>((ref) {
  final c = Supabase.instance.client;
  return EventLogger(c);
});
