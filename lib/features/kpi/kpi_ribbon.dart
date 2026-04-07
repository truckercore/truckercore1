import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'kpi_format.dart';
import 'kpi_providers.dart';

class KpiRibbon extends ConsumerWidget {
  const KpiRibbon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(kpiSnapshotProvider);

    Widget chip(String label, String value) => Chip(
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        );

    Widget skeleton() {
      final base = Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade800
          : Colors.grey.shade300;
      final highlight = Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade700
          : Colors.grey.shade100;
      Widget block(double w) => Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(
              width: w,
              height: 24,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
      final items = [block(140), block(160), block(120), block(180), block(200), block(120)];
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.expand((w) => [w, const SizedBox(width: 8)]).toList()..removeLast(),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: snap.when(
          loading: skeleton,
          error: (e, st) => const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(child: Text('KPIs unavailable — showing zeros')),
            ],
          ),
          data: (k) {
            final items = [
              Semantics(
                label: 'Open Loads, ${k.openLoads}',
                child: chip('Open Loads', '${k.openLoads}'),
              ),
              chip('Fill Rate (7d)', KpiFormat.percent(k.fillRatePct)),
              chip('Avg Rate/mi', KpiFormat.moneyPerMile(k.avgRatePerMile)),
              chip('Time-to-Assign (median)', KpiFormat.minutes(k.timeToAssignMedianMin)),
              Semantics(
                label: 'Active Approved Carriers, ${k.activeApprovedCarriers}',
                child: chip('Active Approved Carriers', '${k.activeApprovedCarriers}'),
              ),
              Semantics(
                label: 'Documents Pending, ${k.docsPending}',
                child: chip('Docs Pending', '${k.docsPending}'),
              ),
            ];
            // If all zeros, show an empty-state hint inline
            final allZero = k.openLoads == 0 && k.fillRatePct == 0 && k.avgRatePerMile == 0 &&
                k.timeToAssignMedianMin == 0 && k.activeApprovedCarriers == 0 && k.docsPending == 0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...items.expand((w) => [w, const SizedBox(width: 8)]).toList()..removeLast(),
                  if (allZero) ...[
                    const SizedBox(width: 12),
                    const Tooltip(
                      message: 'No recent activity in last 7 days',
                      child: Icon(Icons.info_outline, size: 18),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
