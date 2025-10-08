import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/load.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final loadsProvider = FutureProvider<List<Load>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.fetchLoads();
  return response.map((json) => Load.fromJson(json as Map<String, dynamic>)).toList();
});

final loadsByStatusProvider = Provider.family<AsyncValue<List<Load>>, LoadStatus>(
  (ref, status) {
    final loadsAsync = ref.watch(loadsProvider);
    return loadsAsync.whenData(
      (loads) => loads.where((load) => load.status == status).toList(),
    );
  },
);

class LoadNotifier extends StateNotifier<AsyncValue<List<Load>>> {
  LoadNotifier(this.apiService) : super(const AsyncValue.loading()) {
    _loadLoads();
  }

  final ApiService apiService;

  Future<void> _loadLoads() async {
    try {
      final response = await apiService.fetchLoads();
      final loads = response
          .map((json) => Load.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(loads);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadLoads();
  }

  Future<void> postLoad(Load load) async {
    try {
      await apiService.postLoad(load.toJson());
      await _loadLoads();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final loadNotifierProvider =
    StateNotifierProvider<LoadNotifier, AsyncValue<List<Load>>>((ref) {
  return LoadNotifier(ref.watch(apiServiceProvider));
});
