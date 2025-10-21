import 'package:flutter_riverpod/flutter_riverpod.dart';

class Phase3Flags {
  final bool enabled; // FEATURE_PHASE3
  final bool vetting;
  final bool shipper;
  final bool apiKeys;
  final bool mock; // PHASE3_MOCK
  const Phase3Flags({
    required this.enabled,
    required this.vetting,
    required this.shipper,
    required this.apiKeys,
    required this.mock,
  });
}

bool _envBool(String key) {
  const e1 = String.fromEnvironment('FEATURE_PHASE3');
  const e2 = String.fromEnvironment('FEATURE_VETTING');
  const e3 = String.fromEnvironment('FEATURE_SHIPPER');
  const e4 = String.fromEnvironment('FEATURE_API_KEYS');
  const e5 = String.fromEnvironment('PHASE3_MOCK');
  switch (key) {
    case 'FEATURE_PHASE3':
      return e1.toLowerCase() == 'true';
    case 'FEATURE_VETTING':
      return e2.toLowerCase() == 'true';
    case 'FEATURE_SHIPPER':
      return e3.toLowerCase() == 'true';
    case 'FEATURE_API_KEYS':
      return e4.toLowerCase() == 'true';
    case 'PHASE3_MOCK':
      return e5.toLowerCase() == 'true';
  }
  return false;
}

final phase3FlagsProvider = Provider<Phase3Flags>((ref) {
  return Phase3Flags(
    enabled: _envBool('FEATURE_PHASE3'),
    vetting: _envBool('FEATURE_VETTING'),
    shipper: _envBool('FEATURE_SHIPPER'),
    apiKeys: _envBool('FEATURE_API_KEYS'),
    mock: _envBool('PHASE3_MOCK'),
  );
});
