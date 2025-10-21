// lib/core/supabase/widgets/retest_status_card.dart
// Retest Status Card (backoff: next probe time per alert)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supa = Supabase.instance.client;

class RetestStatusCard extends StatefulWidget {
  const RetestStatusCard({super.key});

  @override
  State<RetestStatusCard> createState() => _RetestStatusCardState();
}

class _RetestStatusCardState extends State<RetestStatusCard> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await supa
          .from('alert_retest_state')
          .select('alert_id, tries, next_at')
          .order('next_at')
          .limit(50);
      setState(() => _rows = (data as List).cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatWhen(dynamic val) {
    final parsed = DateTime.tryParse(val?.toString() ?? '');
    if (parsed == null) return val?.toString() ?? '';
    final local = parsed.toLocal();
    final diff = local.difference(DateTime.now());
    final mins = diff.inMinutes;
    if (mins.abs() < 1) return 'now';
    if (mins > 0) return '~${mins}m';
    return '${mins.abs()}m ago';
  }

  Color _statusColor(dynamic ts) {
    final dt = DateTime.tryParse(ts?.toString() ?? '');
    if (dt == null) return Colors.grey;
    final local = dt.toLocal();
    if (local.isBefore(DateTime.now())) return Colors.redAccent;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Retest Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
            if (!_loading && _error == null)
              _rows.isEmpty
                  ? const Text('No retest state yet.')
                  : Column(
                      children: _rows.map((r) {
                        final tries = r['tries']?.toString() ?? '0';
                        final nextAt = r['next_at'];
                        final when = _formatWhen(nextAt);
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.schedule, color: _statusColor(nextAt)),
                          title: Text('Alert: ${r['alert_id']}'),
                          subtitle: Text('tries=$tries • next: $when'),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
          ],
        ),
      ),
    );
  }
}
