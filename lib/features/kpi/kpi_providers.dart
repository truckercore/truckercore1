import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/config/app_config.dart';
import '../../di/supabase_client_provider.dart';
import 'kpi_models.dart';
import 'kpi_repository.dart';

final kpiRepositoryProvider = Provider<KpiRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final supa = ref.watch(supabaseClientProvider);
  if (cfg.useMockData || supa == null) {
    return MockKpiRepository(
      snapshot: const KpiSnapshot(
        openLoads: 0,
        fillRatePct: 0,
        avgRatePerMile: 0.0,
        timeToAssignMedianMin: 0,
        activeApprovedCarriers: 0,
        docsPending: 0,
      ),
    );
  }
  return BasicKpiRepository(client: supa);
});

final kpiFiltersProvider = StateProvider<KpiFilters>((ref) {
  // default to 7-day range
  final now = DateTime.now();
  final range = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
  return KpiFilters(range: range);
});

final kpiSnapshotProvider = FutureProvider<KpiSnapshot>((ref) async {
  final repo = ref.watch(kpiRepositoryProvider);
  final filters = ref.watch(kpiFiltersProvider);
  return repo.get7DaySnapshot(filters: filters);
});
