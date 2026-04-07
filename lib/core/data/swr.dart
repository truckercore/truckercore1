// lib/core/data/swr.dart
// Simple SWR helper: emit cached data quickly, then revalidate via fetcher.

import 'dart:async';
import 'dart:convert';

import '../cache/cache_service.dart';

class Swr {
  static Future<void> getCachedThenRevalidate<T>({
    required String key,
    required Future<T> Function() fetcher,
    required Duration ttl,
    required void Function(T data, DateTime fetchedAt) onUpdate,
    required String Function(T data) toCache,
    required T Function(String cached) fromCache,
  }) async {
    final cache = CacheService.instance;

    // 1) Try cached value asap
    final cachedStr = await cache.getString(key);
    final cachedAt = await cache.getTimestamp(key);
    if (cachedStr != null) {
      try {
        final data = fromCache(cachedStr);
        if (cachedAt != null) {
          onUpdate(data, cachedAt);
        } else {
          onUpdate(data, DateTime.now());
        }
      } catch (_) {
        // ignore cache decode errors
      }
    }

    // 2) If cache is fresh (within ttl), skip revalidate
    final now = DateTime.now();
    if (cachedAt != null && now.difference(cachedAt) <= ttl) {
      return;
    }

    // 3) Revalidate
    final fresh = await fetcher();
    final encoded = toCache(fresh);
    await cache.setString(key, encoded);
    await cache.setTimestamp(key, DateTime.now());
    onUpdate(fresh, DateTime.now());
  }

  // Convenience for list of maps using JSON
  static String jsonEncodeList(List<Map<String, dynamic>> list) => jsonEncode(list);
  static List<Map<String, dynamic>> jsonDecodeList(String s) =>
      (jsonDecode(s) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
