// lib/features/trust/widgets/trust_chip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/flags/rollout_flags.dart';
import '../state/trust_providers.dart';

class TrustChip extends ConsumerWidget {
  const TrustChip({super.key, required this.brokerId});
  final String brokerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(rolloutFlagsProvider);
    if (!flags.explainabilityChipsEnabled) return const SizedBox.shrink();
    final trustAsync = ref.watch(brokerTrustProvider(brokerId));
    return trustAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (score) {
        if (score == null) return const SizedBox.shrink();
        return Tooltip(
          message: 'Broker reliability score based on on-time, disputes, and aging (0-100)',
          child: Chip(label: Text('Trust $score')),
        );
      },
    );
  }
}
