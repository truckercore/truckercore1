// lib/features/fleet/kpis/kpis_controller.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/swr.dart';
import '../../dashboards/services/kpi_service.dart';

class KpisState {
  final DashboardKpis? data;
  final DateTime? lastUpdated;
  final bool isRefreshing;
  const KpisState({this.data, this.lastUpdated, this.isRefreshing = false});
  KpisState copyWith({DashboardKpis? data, DateTime? lastUpdated, bool? isRefreshing}) =>
      KpisState(data: data ?? this.data, lastUpdated: lastUpdated ?? this.lastUpdated, isRefreshing: isRefreshing ?? this.isRefreshing);
}

class KpisController extends StateNotifier<KpisState> {
  final Ref ref;
  KpisController(this.ref) : super(const KpisState());

  static const _cacheKey = 'fleet_kpis_v1';

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true);
    try {
      await Swr.getCachedThenRevalidate<DashboardKpis>(
        key: _cacheKey,
        ttl: const Duration(minutes: 2),
        fetcher: () async {
          final svc = ref.read(kpiServiceProvider);
          return (await svc.fetchKpis()) ?? const DashboardKpis(activeTrucks: 0, deliveries: 0, onTimeRate: 0, km: 0);
        },
        onUpdate: (data, when) {
          state = KpisState(data: data, lastUpdated: when);
        },
        toCache: (d) => jsonEncode({
          'activeTrucks': d.activeTrucks,
          'deliveries': d.deliveries,
          'onTimeRate': d.onTimeRate,
          'km': d.km,
          'deliveriesPrior': d.deliveriesPrior,
          'onTimeRatePrior': d.onTimeRatePrior,
          'kmPrior': d.kmPrior,
        }),
        fromCache: (s) {
          final m = jsonDecode(s) as Map<String, dynamic>;
          return DashboardKpis(
            activeTrucks: m['activeTrucks'] as int,
            deliveries: m['deliveries'] as int,
            onTimeRate: (m['onTimeRate'] as num).toDouble(),
            km: (m['km'] as num).toDouble(),
            deliveriesPrior: m['deliveriesPrior'] as int,
            onTimeRatePrior: (m['onTimeRatePrior'] as num).toDouble(),
            kmPrior: (m['kmPrior'] as num).toDouble(),
          );
        },
      );
    } finally {
      state = state.copyWith(isRefreshing: false);
    }
  }
}

final kpisControllerProvider = StateNotifierProvider<KpisController, KpisState>((ref) => KpisController(ref));
