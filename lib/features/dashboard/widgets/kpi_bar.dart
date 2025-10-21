import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../fleet/data/fleet_repository.dart';

class KpiBar extends StatelessWidget {
  final FleetKpis kpis;
  final bool loading;

  const KpiBar({super.key, required this.kpis, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Row(
        children: List.generate(4, (i) {
          return Expanded(
            child: Container(
              height: 64,
              margin: EdgeInsets.only(right: i < 3 ? 12 : 0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }),
      );
    }

    final nf = NumberFormat.compact();
    final chips = [
      ('Active', nf.format(kpis.activeVehicles)),
      ('Jobs', nf.format(kpis.jobsToday)),
      ('Delays', nf.format(kpis.delays)),
      ('Alerts', nf.format(kpis.alerts)),
    ];

    return Row(
      children: [
        for (var i = 0; i < chips.length; i++)
          Expanded(
            child: Container(
              height: 64,
              margin: EdgeInsets.only(right: i < chips.length - 1 ? 12 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chips[i].$1,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Text(
                    chips[i].$2,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
