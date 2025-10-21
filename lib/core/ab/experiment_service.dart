// lib/core/ab/experiment_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';

class ExperimentAssignment {
  final String experimentKey;
  final String variantKey; // e.g., control | treatment
  const ExperimentAssignment({required this.experimentKey, required this.variantKey});
}

class ExperimentService {
  final AppConfig cfg;
  const ExperimentService(this.cfg);

  Future<ExperimentAssignment?> assign({required String experimentKey, required String userId}) async {
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    final client = Supabase.instance.client;
    try {
      final res = await client.rpc('assign_experiment', params: {
        'p_experiment_key': experimentKey,
        'p_user_id': userId,
      });
      // Expecting something like { variant_key: 'control'|'treatment' }
      if (res is Map) {
        final m = Map<String, dynamic>.from(res);
        final variant = (m['variant_key'] ?? m['variant'] ?? 'control').toString();
        return ExperimentAssignment(experimentKey: experimentKey, variantKey: variant);
      }
      // Some setups return a list
      if (res is List && res.isNotEmpty) {
        final m = Map<String, dynamic>.from(res.first as Map);
        final variant = (m['variant_key'] ?? 'control').toString();
        return ExperimentAssignment(experimentKey: experimentKey, variantKey: variant);
      }
      return ExperimentAssignment(experimentKey: experimentKey, variantKey: 'control');
    } catch (_) {
      // On any failure, default to control
      return ExperimentAssignment(experimentKey: experimentKey, variantKey: 'control');
    }
  }
}

final experimentServiceProvider = Provider<ExperimentService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return ExperimentService(cfg);
});

class ExperimentState {
  final Map<String, ExperimentAssignment> map;
  const ExperimentState(this.map);
}

class ExperimentController extends StateNotifier<ExperimentState> {
  final Ref ref;
  ExperimentController(this.ref) : super(const ExperimentState({}));

  Future<void> ensureAssigned(String experimentKey, String userId) async {
    if (state.map.containsKey(experimentKey)) return;
    final svc = ref.read(experimentServiceProvider);
    final a = await svc.assign(experimentKey: experimentKey, userId: userId);
    if (a != null) {
      final next = Map<String, ExperimentAssignment>.from(state.map);
      next[experimentKey] = a;
      state = ExperimentState(next);
    }
  }

  ExperimentAssignment? get(String experimentKey) => state.map[experimentKey];
}

final experimentControllerProvider = StateNotifierProvider<ExperimentController, ExperimentState>((ref) => ExperimentController(ref));

final rankerVariantIsTreatmentProvider = Provider<bool>((ref) {
  final st = ref.watch(experimentControllerProvider);
  final a = st.map['ranker_v1'];
  return (a?.variantKey ?? 'control') == 'treatment';
});
