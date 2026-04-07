import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeatureFlags {
  final bool safety;
  final bool vehiclesMaintenance;
  final bool compliance;
  final bool fuelSpend;
  final bool helpTraining;

  const FeatureFlags({
    this.safety = true,
    this.vehiclesMaintenance = true,
    this.compliance = true,
    this.fuelSpend = true,
    this.helpTraining = true,
  });
}

/// Simple provider for feature flags. In real deployment, wire to remote config or org settings.
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  // Defaults enabled. Replace with remote values when available.
  return const FeatureFlags();
});
