// lib/features/ranker/widgets/explain_chips.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatting/formatting.dart';
import '../../../core/flags/rollout_flags.dart';
import '../state/ranker_api.dart';

class ExplainChips extends ConsumerWidget {
  const ExplainChips({super.key, required this.item});
  final RankerSuggestion item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(rolloutFlagsProvider);
    if (!flags.explainabilityChipsEnabled) return const SizedBox.shrink();
    final ex = item.explain ?? const {};
    final marketDelta = (ex['market_delta_pct'] as num?)?.toDouble();
    final deadhead = item.deadheadMiles;
    final trust = item.trust;
    final dwellRisk = (ex['dwell_risk_pct'] as num?)?.toDouble();

    final chips = <Widget>[];
    if (marketDelta != null) {
      final sign = marketDelta >= 0 ? '+' : '';
      chips.add(_chip(context, '$sign${marketDelta.toStringAsFixed(0)}% vs market'));
    }
    chips.add(_chip(context, '${formatMiles(deadhead)} deadhead'));
    if (trust != null) chips.add(_chip(context, 'Trust $trust'));
    if (dwellRisk != null) chips.add(_chip(context, 'Dwell ${dwellRisk.toStringAsFixed(0)}%'));

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: -8,
      children: chips
          .map((c) => GestureDetector(
                onLongPress: () {
                  final why = ex['why']?.toString() ?? 'Model signal breakdown unavailable';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Why: $why')),
                  );
                },
                child: c,
              ))
          .toList(),
    );
  }

  Widget _chip(BuildContext context, String text) {
    return Tooltip(message: 'Long-press to see why', child: Chip(label: Text(text)));
  }
}
