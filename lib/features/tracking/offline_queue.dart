// lib/features/tracking/offline_queue.dart
// Durable offline queue for GPS points using SharedPreferences (simple MVP).
// This avoids heavier DBs and works in Flutter unit tests (with mock prefs).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'tracking_service.dart';

abstract class OfflineQueue {
  Future<void> init();
  Future<void> enqueue(GpsPoint p);
  Future<void> enqueueAll(List<GpsPoint> pts);
  Future<List<GpsPoint>> peek(int maxItems);
  Future<void> removeThroughSeq(String deviceId, int lastSeqInclusive);
  Future<int> size();
}

class SharedPrefsQueue implements OfflineQueue {
  SharedPrefsQueue({this.maxEntries = 5000});

  final int maxEntries;
  static const _kKey = 'tracking.queue.v1';

  SharedPreferences? _prefs;
  // In-memory mirror for efficiency
  List<Map<String, dynamic>> _buf = <Map<String, dynamic>>[];

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          _buf = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: true);
        }
      } catch (_) {
        // Corrupt payload — reset
        _buf = <Map<String, dynamic>>[];
      }
    }
  }

  @override
  Future<void> enqueue(GpsPoint p) async {
    await enqueueAll([p]);
  }

  @override
  Future<void> enqueueAll(List<GpsPoint> pts) async {
    if (pts.isEmpty) return;
    _buf.addAll(pts.map((e) => _encode(e)));
    // Cap buffer
    if (_buf.length > maxEntries) {
      _buf = _buf.sublist(_buf.length - maxEntries);
    }
    await _flush();
  }

  @override
  Future<List<GpsPoint>> peek(int maxItems) async {
    final n = maxItems.clamp(0, _buf.length);
    return _buf.take(n).map(_decode).toList(growable: false);
  }

  @override
  Future<void> removeThroughSeq(String deviceId, int lastSeqInclusive) async {
    _buf.removeWhere((m) => m['device_id'] == deviceId && (m['seq'] as int) <= lastSeqInclusive);
    await _flush();
  }

  @override
  Future<int> size() async => _buf.length;

  Map<String, dynamic> _encode(GpsPoint p) => p.toJson();
  GpsPoint _decode(Map<String, dynamic> m) => GpsPoint(
        deviceId: m['device_id'] as String,
        seq: (m['seq'] as num).toInt(),
        ts: DateTime.parse(m['ts'] as String).toUtc(),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        speedMps: (m['speed'] as num?)?.toDouble(),
        activity: (m['activity'] as String?) ?? 'unknown',
      );

  Future<void> _flush() async {
    try {
      await _prefs?.setString(_kKey, jsonEncode(_buf));
    } catch (_) {
      // best-effort
    }
  }
}

/// Persistent last sequence tracker per device.
class SeqStore {
  static String _key(String dev) => 'tracking.last_seq.$dev';

  Future<int> read(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(deviceId)) ?? 0;
    }

  Future<void> write(String deviceId, int seq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(deviceId), seq);
  }
}
