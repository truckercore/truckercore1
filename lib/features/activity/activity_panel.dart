// lib/features/activity/activity_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'activity_service.dart';

class ActivityPanel extends ConsumerStatefulWidget {
  const ActivityPanel({super.key});
  @override
  ConsumerState<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends ConsumerState<ActivityPanel> {
  final _userCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  DateTime? _since;
  final bool _busy = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(activityServiceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.history), SizedBox(width: 8), Text('Activity', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(width: 180, child: TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'User ID', isDense: true))),
              SizedBox(width: 180, child: TextField(controller: _actionCtrl, decoration: const InputDecoration(labelText: 'Action', isDense: true))),
              OutlinedButton.icon(onPressed: _busy ? null : () { setState(() { _since = DateTime.now().subtract(const Duration(days: 1)); }); }, icon: const Icon(Icons.calendar_today, size: 16), label: const Text('Since 24h')),
            ]),
            const SizedBox(height: 8),
            FutureBuilder<List<ActivityItem>>(
              future: svc.list(userId: _userCtrl.text.trim().isEmpty ? null : _userCtrl.text.trim(), action: _actionCtrl.text.trim().isEmpty ? null : _actionCtrl.text.trim(), since: _since),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <ActivityItem>[];
                if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2));
                if (items.isEmpty) return const Text('No activity');
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.bolt),
                      title: Text(it.action),
                      subtitle: Text('${it.at.toLocal()} • ${it.details}'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
