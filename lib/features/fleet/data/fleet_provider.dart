import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/cache/cache_box.dart';
import '../../../core/observability/metrics.dart';
import 'fleet_repository.dart';

// We reuse AttentionItem as our lightweight "FleetItem" for SWR demonstration.
final fleetAttentionProvider = AsyncNotifierProvider<FleetAttentionCtrl, List<AttentionItem>>(FleetAttentionCtrl.new);

class FleetAttentionCtrl extends AsyncNotifier<List<AttentionItem>> {
  static const cacheKey = 'fleet:attention:list';
  final _cache = HiveCacheBox();

  @override
  Future<List<AttentionItem>> build() async {
    await _cache.init();
    final cached = _cache.getJson(cacheKey);
    if (cached != null) {
      final items = _fromListJson(cached['items']);
      // background revalidate
      // ignore: unawaited_futures
      _revalidate();
      return items;
    }
    return _revalidate();
  }

  Future<List<AttentionItem>> _revalidate() async {
    final repo = ref.read(fleetRepositoryProvider);
    Sentry.addBreadcrumb(Breadcrumb(message: 'fetch fleet attention', category: 'repo'));
    final fresh = await trace('api:fetchFleetAttention', () => repo.getNeedsAttention());
    await _cache.putJson(cacheKey, {'items': _toListJson(fresh)});
    state = AsyncData(fresh);
    return fresh;
  }

  Future<void> refreshNow() => _revalidate();

  // Helpers for simple JSON encode/decode without modifying the model classes
  List<Map<String, dynamic>> _toListJson(List<AttentionItem> list) => list
      .map((e) => {
            'id': e.id,
            'title': e.title,
            'subtitle': e.subtitle,
            'severity': e.severity,
          })
      .toList(growable: false);

  List<AttentionItem> _fromListJson(dynamic raw) {
    final arr = (raw as List?) ?? const [];
    return arr
        .whereType<Map>()
        .map((m) => AttentionItem(
              id: '${m['id'] ?? ''}',
              title: '${m['title'] ?? ''}',
              subtitle: '${m['subtitle'] ?? ''}',
              severity: '${m['severity'] ?? 'low'}',
            ))
        .toList(growable: false);
  }
}
