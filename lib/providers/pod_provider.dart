import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pod.dart';
import '../services/api_service.dart';
import 'load_provider.dart' show apiServiceProvider; // reuse

class PODNotifier extends StateNotifier<AsyncValue<List<POD>>> {
  PODNotifier(this.apiService) : super(const AsyncValue.loading());

  final ApiService apiService;

  Future<void> submitPOD(POD pod) async {
    try {
      await apiService.submitPOD(pod.toJson());
      state.whenData((pods) {
        state = AsyncValue.data([pod, ...pods]);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadPODs() async {
    state = const AsyncValue.loading();
    try {
      final response = await apiService.get('pods');
      final pods = (response['pods'] as List?)
              ?.map((json) => POD.fromJson(json as Map<String, dynamic>))
              .toList() ??
          <POD>[];
      state = AsyncValue.data(pods);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final podNotifierProvider =
    StateNotifierProvider<PODNotifier, AsyncValue<List<POD>>>((ref) {
  return PODNotifier(ref.watch(apiServiceProvider));
});
