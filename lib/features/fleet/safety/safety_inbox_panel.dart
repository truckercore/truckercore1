import 'package:flutter/material.dart';
import '../../../services/safety_events_service.dart';

class SafetyInboxPanel extends StatefulWidget {
  final SafetyEventsService svc;
  const SafetyInboxPanel({super.key, required this.svc});
  @override
  State<SafetyInboxPanel> createState() => _SafetyInboxPanelState();
}

class _SafetyInboxPanelState extends State<SafetyInboxPanel> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.svc.listEvents();
  }

  Future<void> _coach(String id) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create coaching note'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Action / feedback'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.svc.createCoachingTask(
        incidentId: id,
        note: ctrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Coaching saved')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            );
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const ListTile(title: Text('No safety events'));
          }
          return Column(
            children: rows.take(10).map((e) {
              return ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text('${e['event_type']} • ${e['severity'] ?? '-'}'),
                subtitle: Text('${e['occurred_at']}'),
                trailing: TextButton(
                  onPressed: () => _coach(e['id'] as String),
                  child: const Text('Coach'),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
