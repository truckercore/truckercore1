// lib/core/supabase/widgets/escalation_log_card.dart
// Escalation Log Card (audit: WARN → P1 etc.)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supa = Supabase.instance.client;

class EscalationLogCard extends StatefulWidget {
  final String? alertId; // optional: filter by a specific alert
  const EscalationLogCard({super.key, this.alertId});

  @override
  State<EscalationLogCard> createState() => _EscalationLogCardState();
}

class _EscalationLogCardState extends State<EscalationLogCard> {
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
      dynamic query = supa
          .from('escalation_events')
          .select('alert_id,from_severity,to_severity,reason,actor,occurred_at')
          .order('occurred_at', ascending: false)
          .limit(25);

      if (widget.alertId != null) {
        query = query.eq('alert_id', widget.alertId);
      }

      final data = await query;
      setState(() => _rows = (data as List).cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                const Text('Escalation Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  ? const Text('No escalation events.')
                  : Column(
                      children: _rows.map((r) {
                        final when = DateTime.tryParse(r['occurred_at']?.toString() ?? '')?.toLocal();
                        final ts = when != null ? when.toString() : (r['occurred_at']?.toString() ?? '');
                        return ListTile(
                          dense: true,
                          title: Text('${r['from_severity']} → ${r['to_severity']} • ${r['reason'] ?? '—'}'),
                          subtitle: Text('Alert: ${r['alert_id']} • Actor: ${r['actor'] ?? 'system'} • $ts'),
                          leading: const Icon(Icons.trending_up),
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
