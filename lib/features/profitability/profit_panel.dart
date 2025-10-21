// lib/features/profitability/profit_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/profit_service.dart';

class ProfitPanel extends ConsumerStatefulWidget {
  const ProfitPanel({super.key});

  @override
  ConsumerState<ProfitPanel> createState() => _ProfitPanelState();
}

class _ProfitPanelState extends ConsumerState<ProfitPanel> {
  bool _loading = false;
  String? _error;
  List<LoadProfitRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = await ref.read(profitServiceProvider).listProfitRows();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Error: $_error'),
      );
    }
    if (_rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'No loads with financials. Add revenue/costs to loads to see P&L.',
        ),
      );
    }

    final totals = _rows.fold<Map<String, int>>(
      {'rev': 0, 'cost': 0, 'profit': 0},
      (acc, r) {
        acc['rev'] = acc['rev']! + r.revenueCents;
        acc['cost'] = acc['cost']! + r.costCents;
        acc['profit'] = acc['profit']! + r.profitCents;
        return acc;
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(
          revenueCents: totals['rev']!,
          costCents: totals['cost']!,
          profitCents: totals['profit']!,
        ),
        const SizedBox(height: 8),
        ..._rows
            .take(10)
            .map(
              (r) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Icon(
                    r.unprofitable ? Icons.trending_down : Icons.trending_up,
                    color: r.unprofitable ? Colors.red : Colors.green,
                  ),
                  title: Text('${r.origin} → ${r.destination}'),
                  subtitle: Text(
                    'Revenue: \$${(r.revenueCents / 100).toStringAsFixed(2)} • Cost: \$${(r.costCents / 100).toStringAsFixed(2)} '
                    '• Profit: \$${(r.profitCents / 100).toStringAsFixed(2)} • Margin: ${r.marginPct.toStringAsFixed(1)}%\n'
                    'Pickup: ${r.pickupAt.toLocal()} • Drop: ${r.dropoffAt.toLocal()}',
                  ),
                  isThreeLine: true,
                  trailing: r.unprofitable
                      ? TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Open cost breakdown coming soon',
                                ),
                              ),
                            );
                          },
                          child: const Text('Investigate'),
                        )
                      : null,
                ),
              ),
            ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Recompute'),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int revenueCents;
  final int costCents;
  final int profitCents;
  const _SummaryRow({
    required this.revenueCents,
    required this.costCents,
    required this.profitCents,
  });

  @override
  Widget build(BuildContext context) {
    final margin = revenueCents == 0 ? 0 : (profitCents / revenueCents) * 100.0;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _Chip(
          label: 'Revenue',
          value: '\$${(revenueCents / 100).toStringAsFixed(2)}',
          color: Colors.blue,
        ),
        _Chip(
          label: 'Cost',
          value: '\$${(costCents / 100).toStringAsFixed(2)}',
          color: Colors.orange,
        ),
        _Chip(
          label: 'Profit',
          value: '\$${(profitCents / 100).toStringAsFixed(2)}',
          color: profitCents >= 0 ? Colors.green : Colors.red,
        ),
        _Chip(
          label: 'Margin',
          value: '${margin.toStringAsFixed(1)}%',
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text('$label: $value'),
    );
  }
}
