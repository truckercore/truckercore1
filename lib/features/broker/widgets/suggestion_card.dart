// lib/features/broker/widgets/suggestion_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ab/experiment_service.dart';
import '../../../core/analytics/kpi_analytics.dart';
import '../../../core/flags/rollout_flags.dart';
import '../ranker/ranker_service.dart';
class SuggestionCard extends ConsumerWidget {
  final RankerItem item;
  const SuggestionCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(rolloutFlagsProvider);
    final isTreatment = ref.watch(rankerVariantIsTreatmentProvider);
    kpiMaybeEmitSuggestionView(ref, item.loadId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text('Load ${item.loadId}', style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(item.score.toStringAsFixed(2), style: const TextStyle(fontFeatures: [])),
              ],
            ),
            const SizedBox(height: 8),
            if (flags.explainabilityChipsEnabled && isTreatment)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Compliance badge (placeholder; real call can annotate item)
                  if (flags.complianceValidatorV1Enabled)
                    Tooltip(
                      message: 'Compliance-checked',
                      child: Chip(
                        avatar: const Icon(Icons.verified, size: 16, color: Colors.green),
                        label: const Text('Compliance-checked'),
                        backgroundColor: Colors.green.shade50,
                      ),
                    ),
                  // Delay risk badge (placeholder; real service can compute and label severity)
                  if (flags.delayPredictionV1Enabled)
                    Tooltip(
                      message: 'Late risk: heuristic',
                      child: Chip(
                        avatar: const Icon(Icons.schedule, size: 16, color: Colors.orange),
                        label: const Text('Late risk: medium'),
                        backgroundColor: Colors.orange.shade50,
                      ),
                    ),
                  for (final ex in item.explain.take(4)) Tooltip(
                    message: ex['label'] ?? '',
                    child: Chip(label: Text(ex['label'] ?? '')),
                  ),
                  if (item.lowConfidence)
                    Chip(
                      avatar: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Low confidence'),
                      backgroundColor: Colors.amber.shade50,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
