import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_finance_service.dart';
import '../../services/supabase_safe.dart';

class AiProfitTipsPanel extends ConsumerStatefulWidget {
  const AiProfitTipsPanel({super.key});
  @override
  ConsumerState<AiProfitTipsPanel> createState() => _AiProfitTipsPanelState();
}

class _AiProfitTipsPanelState extends ConsumerState<AiProfitTipsPanel> {
  late Future<List<AiFinancialRecommendation>> _future;
  @override
  void initState() {
    super.initState();
    final client = SupabaseSafe.clientOrNull;
    final uid = client?.auth.currentUser?.id;
    _future = uid == null
        ? Future.value(const [])
        : ref.read(aiFinanceServiceProvider).lastRecsForUser(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.savings_outlined),
                SizedBox(width: 8),
                Text('Profit Tips'),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<AiFinancialRecommendation>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return const Text('No recommendations yet.');
                }
                int total = 0;
                for (final r in rows.take(3)) {
                  total += r.projectedSavingsCents;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      label: Text(
                        'Top 3 savings: \$${(total / 100).toStringAsFixed(0)}',
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...rows
                        .take(10)
                        .map(
                          (r) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.lightbulb_outline),
                            title: Text(r.text),
                            subtitle: Text(
                              'Savings: \$${(r.projectedSavingsCents / 100).toStringAsFixed(0)}',
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
