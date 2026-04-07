import 'package:flutter/material.dart';
import '../widgets/escalation_log_card.dart';
import '../widgets/remediation_effectiveness_card.dart';
import '../widgets/retest_status_card.dart';

class SecurityDashboard extends StatelessWidget {
  const SecurityDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brokerScheme = scheme.copyWith(primary: Colors.teal);

    return Scaffold(
      appBar: AppBar(title: const Text('Security & Quality')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 1000;
            final children = [
              const EscalationLogCard(),
              RetestStatusCard(colorSchemeOverride: brokerScheme),
              const RemediationEffectivenessCard(),
            ];
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children
                    .map((w) => Expanded(child: Padding(padding: const EdgeInsets.all(8), child: w)))
                    .toList(),
              );
            }
            return ListView(
              children: children.map((w) => Padding(padding: const EdgeInsets.all(8), child: w)).toList(),
            );
          },
        ),
      ),
    );
  }
}
