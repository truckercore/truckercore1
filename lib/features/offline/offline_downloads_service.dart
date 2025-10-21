import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal offline downloads tracker. Stores region_keys the user marked
/// for offline use (e.g., tiles + POIs per region).
class OfflineDownloadsService {
  static const _prefsKey = 'offline.downloaded_regions.v1';

  final ValueNotifier<Set<String>> _regions = ValueNotifier<Set<String>>({});
  bool _loaded = false;

  ValueListenable<Set<String>> get regions => _regions;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<String>();
        _regions.value = {...list};
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<Set<String>> listRegions() async {
    await _ensureLoaded();
    return {..._regions.value};
  }

  Future<void> addRegion(String regionKey) async {
    await _ensureLoaded();
    final next = {..._regions.value}..add(regionKey);
    _regions.value = next;
    await _persist();
  }

  Future<void> removeRegion(String regionKey) async {
    await _ensureLoaded();
    final next = {..._regions.value}..remove(regionKey);
    _regions.value = next;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_regions.value.toList()),
      );
    } catch (_) {}
  }
}

final offlineDownloadsServiceProvider = Provider<OfflineDownloadsService>(
  (ref) => OfflineDownloadsService(),
);
