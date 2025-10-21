// lib/core/cache/cache_service.dart
// Lightweight cache with in-memory map + SharedPreferences backing store.
// Values are stored as strings; callers can encode/decode JSON as needed.

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  final Map<String, String> _mem = <String, String>{};

  Future<void> setString(String key, String value) async {
    _mem[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {
      // Ignore persistence errors; rely on in-memory cache
    }
  }

  Future<String?> getString(String key) async {
    final v = _mem[key];
    if (v != null) return v;
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(key);
      if (s != null) _mem[key] = s;
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    _mem.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  // Helpers for timestamps per key (used by SWR)
  String _tsKey(String key) => '${key}__ts';

  Future<void> setTimestamp(String key, DateTime when) async {
    await setString(_tsKey(key), when.millisecondsSinceEpoch.toString());
  }

  Future<DateTime?> getTimestamp(String key) async {
    final s = await getString(_tsKey(key));
    if (s == null) return null;
    final ms = int.tryParse(s);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
