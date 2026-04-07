import 'package:flutter/material.dart';
import '../core/supabase/client.dart';
import '../ui/empty_state.dart';
import '../ui/theming.dart';

class RetestStatusCard extends StatefulWidget {
  final String title;
  final ColorScheme? colorSchemeOverride;

  const RetestStatusCard({
    super.key,
    this.title = 'Retest Status',
    this.colorSchemeOverride,
  });

  @override
  State<RetestStatusCard> createState() => _RetestStatusCardState();
}

class _RetestStatusCardState extends State<RetestStatusCard> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await TC.guard(() => TC.db
        .from('retests_view') // Materialized/normal view suggested below
        .select()
        .order('next_retest_at'));
    setState(() {
      _rows = (data as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        : _rows.isEmpty
            ? const EmptyState(
                title: 'No pending retests',
                tip: 'All remediations have been verified. Great job!',
              )
            : Column(
                children: _rows.map((r) {
                  final title = r['alert_title'] ?? 'Alert';
                  final status = r['retest_status'] ?? 'unknown';
                  final next = r['next_retest_at'] as String?;
                  return ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: Text(title),
                    subtitle: Text('Status: $status • Next: ${next ?? 'n/a'}'),
                  );
                }).toList(),
              );

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
