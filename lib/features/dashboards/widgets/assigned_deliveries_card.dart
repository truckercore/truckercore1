import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/services/loads_service.dart';
import '../../../common/widgets/error_card.dart';
import '../../../common/widgets/section_header.dart';
import '../../../common/widgets/skeleton_list.dart';
import '../../../widgets/loading_action_button.dart';

class AssignedDeliveriesCard extends ConsumerWidget {
  const AssignedDeliveriesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadsSvc = ref.watch(loadsServiceProvider);
    return FutureBuilder(
      future: loadsSvc.listAssignedToMe(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        final first = items.isNotEmpty ? items.first : null;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Assigned Deliveries',
                  trailing: TextButton(
                    onPressed: () => context.push('/loads'),
                    child: const Text('Open Loads'),
                  ),
                ),
                const SizedBox(height: 8),
                if (snap.connectionState == ConnectionState.waiting)
                  const SkeletonList(itemHeight: 64)
                else if (snap.hasError)
                  ErrorCard(
                    message: 'Failed to load: ${snap.error}',
                    onRetry: () => (context as Element).markNeedsBuild(),
                  )
                else ...[
                  if (items.isEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.inbox_outlined, color: Colors.grey),
                        const SizedBox(width: 6),
                        const Text('Nothing assigned yet.'),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push('/marketplace'),
                          child: const Text('Browse Marketplace'),
                        ),
                      ],
                    ),
                  ],
                  if (first != null) ...[
                    ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text('${first.origin} → ${first.destination}'),
                      subtitle: Text('Pickup ${first.pickupAt.toLocal()}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/loads/${first.id}'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        LoadingActionButton(
                          onPressed: () async {
                            try {
                              final c = Supabase.instance.client;
                              await c.from('dispatch_events').insert({
                                'event_type': 'assignment_accepted',
                                'details': {'load_id': first.id},
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Assignment accepted.')),
                                );
                              }
                            } catch (_) {}
                          },
                          child: const Text('Accept'),
                        ),
                        LoadingActionButton(
                          style: OutlinedButton.styleFrom(),
                          onPressed: () async {
                            try {
                              final c = Supabase.instance.client;
                              await c.from('dispatch_events').insert({
                                'event_type': 'assignment_declined',
                                'details': {'load_id': first.id},
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Assignment declined.')),
                                );
                              }
                            } catch (_) {}
                          },
                          child: const Text('Decline'),
                        ),
                        LoadingActionButton(
                          style: OutlinedButton.styleFrom(),
                          onPressed: () async {
                            try {
                              await loadsSvc.updateStatus(loadId: first.id, status: 'in_transit');
                              await Supabase.instance.client.from('dispatch_events').insert({
                                'event_type': 'trip_started',
                                'details': {'load_id': first.id},
                              });
                            } catch (_) {}
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Trip started.')),
                              );
                            }
                          },
                          child: const Text('Start Trip'),
                        ),
                      ],
                    ),
                  ],
                  if (items.length > 1) const Divider(),
                  for (final l in items.skip(1).take(2))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text('${l.origin} → ${l.destination}'),
                      subtitle: Text('Pickup ${l.pickupAt.toLocal()}'),
                      onTap: () => context.push('/loads/${l.id}'),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
