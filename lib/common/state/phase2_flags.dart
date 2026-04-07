import 'package:flutter_riverpod/flutter_riverpod.dart';

class Phase2Flags {
  final bool marketRates;
  final bool trihaul;
  final bool brokerCredit;
  final bool mock; // PHASE2_MOCK
  const Phase2Flags({
    required this.marketRates,
    required this.trihaul,
    required this.brokerCredit,
    required this.mock,
  });
}

bool _envBool(String key, {bool def = false}) {
  const m = String.fromEnvironment('FEATURE_MARKET_RATES');
  const t = String.fromEnvironment('FEATURE_TRIHAUL');
  const b = String.fromEnvironment('FEATURE_BROKER_CREDIT');
  const mock = String.fromEnvironment('PHASE2_MOCK');
  switch (key) {
    case 'FEATURE_MARKET_RATES':
      return (m.toLowerCase() == 'true');
    case 'FEATURE_TRIHAUL':
      return (t.toLowerCase() == 'true');
    case 'FEATURE_BROKER_CREDIT':
      return (b.toLowerCase() == 'true');
    case 'PHASE2_MOCK':
      return (mock.toLowerCase() == 'true');
  }
  return def;
}

final phase2FlagsProvider = Provider<Phase2Flags>((ref) {
  return Phase2Flags(
    marketRates: _envBool('FEATURE_MARKET_RATES'),
    trihaul: _envBool('FEATURE_TRIHAUL'),
    brokerCredit: _envBool('FEATURE_BROKER_CREDIT'),
    mock: _envBool('PHASE2_MOCK'),
  );
});
