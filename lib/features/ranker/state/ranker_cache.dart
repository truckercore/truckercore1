// lib/features/ranker/state/ranker_cache.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ranker_api.dart';

/// A tiny cache keyed by normalized {query+filters}.
/// Uses SharedPreferences for persistence when available; also keeps an in-memory map
/// to reduce JSON (de)serialization hot paths.
class RankerCache {
  static const _prefix = 'ranker_cache:';
  final _mem = <String, _CacheEntry>{};

  Future<RankerResponse?> get(String key) async {
    final inMem = _mem[key];
    if (inMem != null) return inMem.payload;
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = _CacheEntry.fromJson(map);
      _mem[key] = entry;
      return entry.payload;
    } catch (_) {
      return null;
    }
  }

  Future<void> set(String key, RankerResponse value) async {
    final entry = _CacheEntry(
      ts: value.ts,
      payload: value,
    );
    _mem[key] = entry;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('$_prefix$key', jsonEncode(entry.toJson()));
  }

  Future<void> clearOld(Duration ttl) async {
    final now = DateTime.now().toUtc();
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys().where((k) => k.startsWith(_prefix)).toList(growable: false);
    for (final k in keys) {
      final raw = sp.getString(k);
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final entry = _CacheEntry.fromJson(map);
        if (now.difference(entry.ts) > ttl) {
          await sp.remove(k);
          _mem.remove(k.substring(_prefix.length));
        }
      } catch (_) {}
    }
  }

  static String normalizeKey({required String query, required Map<String, dynamic> filters}) {
    // Stable JSON encoding with sorted keys.
    final sorted = Map<String, dynamic>.fromEntries(
      filters.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final payload = {'q': query.trim().toLowerCase(), 'f': sorted};
    return base64Url.encode(utf8.encode(jsonEncode(payload)));
  }
}

class _CacheEntry {
  final DateTime ts;
  final RankerResponse payload;
  const _CacheEntry({required this.ts, required this.payload});

  Map<String, dynamic> toJson() => {
        'ts': ts.toIso8601String(),
        'payload': payload.toJson(),
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> j) => _CacheEntry(
        ts: DateTime.parse(j['ts'] as String).toUtc(),
        payload: RankerResponse.fromJson((j['payload'] as Map).cast<String, dynamic>()),
      );
}

final rankerCacheProvider = Provider<RankerCache>((ref) => RankerCache());
