// lib/features/safety/state/safety_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/config/app_config.dart';

/// Safety feature providers (DVR, alerts, score thresholds)

/// Global on/off flag for safety features (could be wired to remote flags)
final safetyFeaturesEnabledProvider = StateProvider<bool>((ref) => true);

/// Thresholds for generating alerts; can be tuned per environment
class SafetyThresholds {
  final double harshBrakingMps2;
  final double speedingOverKph;
  const SafetyThresholds({this.harshBrakingMps2 = 4.0, this.speedingOverKph = 10});
}

final safetyThresholdsProvider = Provider<SafetyThresholds>((ref) => const SafetyThresholds());

/// Example safety API token/id hidden behind a provider. Uses AppConfig to centralize config.
final safetyApiTokenProvider = Provider<String>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final token = cfg.mapboxToken; // placeholder token usage pattern
  if (token.isEmpty) {
    if (cfg.useMockData) return '';
    throw StateError('Safety API token is not configured');
  }
  return token;
});

/// Experimental toggles useful during development
final safetyExperimentsEnabledProvider = StateProvider<bool>((ref) => !kReleaseMode);
