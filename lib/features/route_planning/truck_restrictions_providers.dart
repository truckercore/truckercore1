import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_provider.dart';
import 'truck_restrictions.dart';
import 'truck_restrictions_repository.dart';

// A no-op repository used in mock/disabled environments
class NoopTruckRestrictionsRepository extends TruckRestrictionsRepository {
  NoopTruckRestrictionsRepository() : super(null);

  @override
  Future<List<TruckRestriction>> fetchByState(String stateCode, {int limit = 500}) async => const [];

  @override
  Future<List<TruckRestriction>> fetchOverlaysByStateRpc(String stateCode, {int limit = 800}) async => const [];

  @override
  Future<List<Map<String, dynamic>>> checkRouteHazardsSimple({
    required List<List<double>> polylineLatLngs,
    double? trailerHeightFt,
  }) async => const [];
}

final truckRestrictionsRepositoryProvider = Provider<TruckRestrictionsRepository>((ref) {
  final env = ref.watch(appEnvProvider);
  final client = ref.watch(supabaseClientProvider);
  if (env.useMockData || client == null) return NoopTruckRestrictionsRepository();
  return TruckRestrictionsRepository(client);
});
