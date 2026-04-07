// lib/core/flags/rollout_flags.dart
// Feature flags scaffold for sprint rollout
// Load from --dart-define; later we can augment with remote config.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RolloutFlags {
  final bool swrEnabled;
  final bool realtimeFallbackPollingEnabled;
  final bool statusBannerEnabled;
  final bool friendlyErrorsEnabled;
  final bool rankerV1Enabled;
  final bool explainabilityChipsEnabled;
  final bool personalizationV1Enabled;
  final bool backhaulV1Enabled;
  final bool complianceValidatorV1Enabled;
  final bool negotiationAssistantV1Enabled;
  final bool delayPredictionV1Enabled;

  const RolloutFlags({
    required this.swrEnabled,
    required this.realtimeFallbackPollingEnabled,
    required this.statusBannerEnabled,
    required this.friendlyErrorsEnabled,
    required this.rankerV1Enabled,
    required this.explainabilityChipsEnabled,
    required this.personalizationV1Enabled,
    required this.backhaulV1Enabled,
    required this.complianceValidatorV1Enabled,
    required this.negotiationAssistantV1Enabled,
    required this.delayPredictionV1Enabled,
  });

  RolloutFlags copyWith({
    bool? swrEnabled,
    bool? realtimeFallbackPollingEnabled,
    bool? statusBannerEnabled,
    bool? friendlyErrorsEnabled,
    bool? rankerV1Enabled,
    bool? explainabilityChipsEnabled,
    bool? personalizationV1Enabled,
    bool? backhaulV1Enabled,
    bool? complianceValidatorV1Enabled,
    bool? negotiationAssistantV1Enabled,
    bool? delayPredictionV1Enabled,
  }) => RolloutFlags(
        swrEnabled: swrEnabled ?? this.swrEnabled,
        realtimeFallbackPollingEnabled: realtimeFallbackPollingEnabled ?? this.realtimeFallbackPollingEnabled,
        statusBannerEnabled: statusBannerEnabled ?? this.statusBannerEnabled,
        friendlyErrorsEnabled: friendlyErrorsEnabled ?? this.friendlyErrorsEnabled,
        rankerV1Enabled: rankerV1Enabled ?? this.rankerV1Enabled,
        explainabilityChipsEnabled: explainabilityChipsEnabled ?? this.explainabilityChipsEnabled,
        personalizationV1Enabled: personalizationV1Enabled ?? this.personalizationV1Enabled,
        backhaulV1Enabled: backhaulV1Enabled ?? this.backhaulV1Enabled,
        complianceValidatorV1Enabled: complianceValidatorV1Enabled ?? this.complianceValidatorV1Enabled,
        negotiationAssistantV1Enabled: negotiationAssistantV1Enabled ?? this.negotiationAssistantV1Enabled,
        delayPredictionV1Enabled: delayPredictionV1Enabled ?? this.delayPredictionV1Enabled,
      );
}

// Defaults ON in staging; can be toggled off in prod via --dart-define
const rolloutFlagsFromEnv = RolloutFlags(
  swrEnabled: bool.fromEnvironment('FLAG_SWR_ENABLED', defaultValue: true),
  realtimeFallbackPollingEnabled: bool.fromEnvironment('FLAG_RT_FALLBACK_ENABLED', defaultValue: true),
  statusBannerEnabled: bool.fromEnvironment('FLAG_STATUS_BANNER_ENABLED', defaultValue: true),
  friendlyErrorsEnabled: bool.fromEnvironment('FLAG_FRIENDLY_ERRORS_ENABLED', defaultValue: true),
  rankerV1Enabled: bool.fromEnvironment('FLAG_RANKER_V1', defaultValue: true),
  explainabilityChipsEnabled: bool.fromEnvironment('FLAG_EXPLAINABILITY_CHIPS', defaultValue: true),
  personalizationV1Enabled: bool.fromEnvironment('FLAG_PERSONALIZATION_V1', defaultValue: true),
  backhaulV1Enabled: bool.fromEnvironment('FLAG_BACKHAUL_V1', defaultValue: true),
  complianceValidatorV1Enabled: bool.fromEnvironment('FLAG_COMPLIANCE_VALIDATOR_V1', defaultValue: true),
  negotiationAssistantV1Enabled: bool.fromEnvironment('FLAG_NEGOTIATION_ASSISTANT_V1', defaultValue: true),
  delayPredictionV1Enabled: bool.fromEnvironment('FLAG_DELAY_PREDICTION_V1', defaultValue: true),
);

final rolloutFlagsProvider = StateProvider<RolloutFlags>((ref) => rolloutFlagsFromEnv);

// Optional helper to log current flags in debug mode
void debugPrintFlags(RolloutFlags f) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[flags] swr=${f.swrEnabled} rtFallback=${f.realtimeFallbackPollingEnabled} status=${f.statusBannerEnabled} friendly=${f.friendlyErrorsEnabled} ranker=${f.rankerV1Enabled} explain=${f.explainabilityChipsEnabled} personalize=${f.personalizationV1Enabled} backhaul=${f.backhaulV1Enabled}');
  }
}
