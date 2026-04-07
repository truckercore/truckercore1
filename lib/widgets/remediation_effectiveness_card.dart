import 'package:flutter/material.dart';
import '../core/supabase/client.dart';
import '../ui/empty_state.dart';
import '../ui/theming.dart';

class RemediationEffectivenessCard extends StatefulWidget {
  final String title;
  final ColorScheme? colorSchemeOverride;

  const RemediationEffectivenessCard({
    super.key,
    this.title = 'Remediation Effectiveness (Quarterly)',
    this.colorSchemeOverride,
  });

  @override
  State<RemediationEffectivenessCard> createState() => _RemediationEffectivenessCardState();
}

class _RemediationEffectivenessCardState extends State<RemediationEffectivenessCard> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await TC.guard(() => TC.db
        .from('remediation_effectiveness_quarterly')
        .select()
        .order('year')
        .order('quarter'));
    setState(() {
      _rows = (data as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_rows.isEmpty) {
      body = const EmptyState(
        title: 'No remediation data',
        tip: 'Ship a few fixes and retests — we’ll chart effectiveness here.',
      );
    } else {
      body = Column(
        children: _rows.map((r) {
          final y = r['year'];
          final q = r['quarter'];
          final total = r['total'] ?? 0;
          final passed = r['passed'] ?? 0;
          final rate = (r['pass_rate'] ?? 0.0) as num;

          // Tiny inline bar: pass rate as a simple progress bar (no extra deps)
          final pct = rate.toDouble().clamp(0.0, 1.0);

          return ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: Text('Q$q $y'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Passed $passed / $total • Rate ${(pct * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct == 0 && total == 0 ? null : pct,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return CardThemeWrapper(
      colorSchemeOverride: widget.colorSchemeOverride,
      child: Card(
        elevation: 2,
        child: Column(
          children: [
            ListTile(title: Text(widget.title)),
            const Divider(height: 1),
            body,
          ],
        ),
      ),
    );
  }
}
