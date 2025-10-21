import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'saved_search_service.dart';

class AlertsBell extends ConsumerWidget {
  const AlertsBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unseenAlertsCountProvider);
    final count = countAsync.asData?.value ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Alerts',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => const AlertsDrawer(),
            );
          },
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class AlertsDrawer extends ConsumerStatefulWidget {
  const AlertsDrawer({super.key});
  @override
  ConsumerState<AlertsDrawer> createState() => _AlertsDrawerState();
}

class _AlertsDrawerState extends ConsumerState<AlertsDrawer> {
  late Future<List<AlertItem>> _fut;
  bool _showUnseenOnly = true;

  @override
  void initState() {
    super.initState();
    _fut = ref
        .read(savedSearchServiceProvider)
        .listMyAlerts(unseenOnly: _showUnseenOnly);
  }

  Future<void> _reload() async {
    setState(() {
      _fut = ref
          .read(savedSearchServiceProvider)
          .listMyAlerts(unseenOnly: _showUnseenOnly);
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.read(savedSearchServiceProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 8),
                const Text('Alerts'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await svc.markAllSeen();
                    await _reload();
                  },
                  icon: const Icon(Icons.done_all),
                  label: const Text('Mark all seen'),
                ),
              ],
            ),
            Row(
              children: [
                FilterChip(
                  label: const Text('Unseen only'),
                  selected: _showUnseenOnly,
                  onSelected: (v) {
                    setState(() => _showUnseenOnly = v);
                    _reload();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
              ],
            ),
            const Divider(),
            FutureBuilder<List<AlertItem>>(
              future: _fut,
              builder: (context, snap) {
                final items = snap.data ?? const <AlertItem>[];
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No alerts')),
                  );
                }
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final a = items[i];
                      return ListTile(
                        leading: const Icon(Icons.notifications),
                        title: Text(a.title),
                        subtitle: Text(
                          '${a.subtitle}\n${a.triggeredAt.toLocal()}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            TextButton(
                              onPressed: () => context.push(a.deeplink),
                              child: const Text('View'),
                            ),
                            IconButton(
                              tooltip: 'Mark seen',
                              icon: const Icon(Icons.visibility),
                              onPressed: () async {
                                await svc.markSeen(a.id);
                                await _reload();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
