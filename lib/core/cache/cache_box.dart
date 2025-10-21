import 'package:hive_flutter/hive_flutter.dart';

/// Lightweight cache entry for typed use (kept generic for future evolution)
class CacheEntry<T> {
  final T data;
  final DateTime fetchedAt;
  CacheEntry(this.data, this.fetchedAt);
}

abstract class CacheBox {
  Future<void> init();
  Future<void> putJson(String key, Map<String, dynamic> json);
  Map<String, dynamic>? getJson(String key);
  DateTime? getFetchedAt(String key);
}

class HiveCacheBox implements CacheBox {
  late Box _box;

  @override
  Future<void> init() async {
    // Safe to call multiple times; Hive guards internal init
    await Hive.initFlutter();
    _box = await Hive.openBox('rd_cache');
  }

  @override
  Future<void> putJson(String k, Map<String, dynamic> v) async {
    await _box.put(k, v);
    await _box.put('${k}__at', DateTime.now().toIso8601String());
  }

  @override
  Map<String, dynamic>? getJson(String k) => (_box.get(k) as Map?)?.cast<String, dynamic>();

  @override
  DateTime? getFetchedAt(String k) {
    final s = _box.get('${k}__at') as String?;
    return s != null ? DateTime.tryParse(s) : null;
  }
}
