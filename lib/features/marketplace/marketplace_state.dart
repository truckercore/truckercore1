import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/marketplace_service.dart';
import '../../shared/telemetry/telemetry.dart';

class MarketplaceFilters {
  final String equipment; // 'any'|'dry_van'|'reefer'|'flatbed'|...
  final double? minDollarPerMile; // null = no min
  final String query; // free-text search
  final double? maxDeadheadMiles; // advanced
  final DateTime? pickupDate; // advanced
  const MarketplaceFilters({
    this.equipment = 'any',
    this.minDollarPerMile,
    this.query = '',
    this.maxDeadheadMiles,
    this.pickupDate,
  });
  MarketplaceFilters copyWith({
    String? equipment,
    double? minDollarPerMile,
    String? query,
    double? maxDeadheadMiles,
    DateTime? pickupDate,
  }) =>
      MarketplaceFilters(
        equipment: equipment ?? this.equipment,
        minDollarPerMile: minDollarPerMile ?? this.minDollarPerMile,
        query: query ?? this.query,
        maxDeadheadMiles: maxDeadheadMiles ?? this.maxDeadheadMiles,
        pickupDate: pickupDate ?? this.pickupDate,
      );
}

class MarketplaceState {
  final MarketplaceFilters filters;
  final bool loading;
  final String? error;
  final List<MarketplaceLoad> results;
  final DateTime? lastUpdated;
  const MarketplaceState({required this.filters, required this.loading, required this.error, required this.results, required this.lastUpdated});
  factory MarketplaceState.initial() => const MarketplaceState(filters: MarketplaceFilters(), loading: false, error: null, results: [], lastUpdated: null);
  MarketplaceState copyWith({MarketplaceFilters? filters, bool? loading, String? error, List<MarketplaceLoad>? results, DateTime? lastUpdated}) =>
      MarketplaceState(filters: filters ?? this.filters, loading: loading ?? this.loading, error: error, results: results ?? this.results, lastUpdated: lastUpdated ?? this.lastUpdated);
}

class MarketplaceController extends StateNotifier<MarketplaceState> {
  // Heuristic: show refine banner if zero results or results < 5 when a query exists,
  // or if minDollarPerMile is null and observed rpm median is far from a notional target (stubbed)
  bool get shouldShowRefineBanner {
    final hasQuery = state.filters.query.trim().isNotEmpty || state.filters.equipment != 'any';
    final few = state.results.length <= 2;
    return hasQuery && few;
  }
  MarketplaceController(this._ref): super(MarketplaceState.initial());
  final Ref _ref;
  Timer? _debounce;

  void setEquipment(String value){
    state = state.copyWith(filters: state.filters.copyWith(equipment: value));
  }
  void setMinDollarPerMile(double? value){
    state = state.copyWith(filters: state.filters.copyWith(minDollarPerMile: value));
  }
  void setQuery(String value){
    state = state.copyWith(filters: state.filters.copyWith(query: value));
  }

  Future<void> search({bool debounced = false}) async {
    if (debounced){
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), (){ search(); });
      return;
    }
    state = state.copyWith(loading: true);
    try{
      final svc = _ref.read(marketplaceServiceProvider);
      final list = await svc.fetchOpenLoads(
        originQ: state.filters.query.isEmpty ? null : state.filters.query,
        equipment: state.filters.equipment,
      );
      // Apply min $/mi filter client-side for now (requires pay and miles if available). We only have pay_cents; assume estimated_miles if present.
      final filtered = state.filters.minDollarPerMile == null ? list : list.where((l){
        final miles =  l.dropoffAt.difference(l.pickupAt).inHours.abs().clamp(1, 9999); // placeholder miles if none
        final rpm = miles == 0 ? 0 : (l.payCents/100.0)/miles;
        return rpm >= (state.filters.minDollarPerMile ?? 0);
      }).toList();
      state = state.copyWith(results: filtered, loading: false, lastUpdated: DateTime.now());
    } catch (e){
      state = state.copyWith(error: 'network', loading: false);
    }
  }

  void relaxFiltersAndRetry(){
    state = state.copyWith(filters: const MarketplaceFilters());
    Telemetry.event('empty_results_retry', {'action': 'relax_filters'});
    unawaited(search());
  }
  void retry(){
    Telemetry.event('empty_results_retry', {'action': 'retry', 'equipment': state.filters.equipment, 'minDollarPerMile': state.filters.minDollarPerMile});
    unawaited(search());
  }
}

final marketplaceProvider = StateNotifierProvider<MarketplaceController, MarketplaceState>((ref){
  return MarketplaceController(ref);
});
