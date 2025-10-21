import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/state/session_provider.dart';
import '../../../common/widgets/app_background.dart';
import '../../owner_op/free_caps/free_caps.dart';
import 'roaddogg_service.dart';

class RoadDoggScreen extends ConsumerStatefulWidget {
  const RoadDoggScreen({super.key});
  @override
  ConsumerState<RoadDoggScreen> createState() => _RoadDoggScreenState();
}

class _RoadDoggScreenState extends ConsumerState<RoadDoggScreen> {
  final _textCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  List<RoadDoggSuggestion> _results = const [];
  int _weeklyUsed = 0; // for free meter
  final Set<String> _requestedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _refreshWeeklyCap();
  }

  Future<void> _refreshWeeklyCap() async {
    try {
      final used = await ref.read(roadDoggServiceProvider).weeklyQueryCount();
      if (mounted) setState(() => _weeklyUsed = used);
    } catch (_) {}
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
      _results = const [];
    });
    try {
      final isPremium = ref.read(sessionProvider).isPremium;
      // Free-tier enforcement: 3 queries/week
      if (!isPremium) {
        final used = await ref.read(roadDoggServiceProvider).weeklyQueryCount();
        if (used >= 3) {
          debugPrint('[ANALYTICS] roaddogg_free_limit_hit type=queries');
          if (mounted) {
            await showDialog(
              context: context,
              builder: (_) => const _UpgradeDialog(),
            );
          }
          setState(() {
            _busy = false;
          });
          return;
        }
      }
      final suggestions = await ref
          .read(roadDoggServiceProvider)
          .findSuggestions(
            text: _textCtrl.text,
            filters: {},
            isPremium: ref.read(sessionProvider).isPremium,
          );
      setState(() {
        _results = suggestions;
      });
      // After successful results, refresh meter (Free tier counter decrements now that results are returned)
      await _refreshWeeklyCap();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(sessionProvider).isPremium;
    debugPrint(
      "[ANALYTICS] roaddogg_opened tier=${isPremium ? 'premium' : 'free'}",
    );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RoadDogg Assistant'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Results'),
              Tab(icon: Icon(Icons.bookmarks_outlined), text: 'My Loads'),
              Tab(icon: Icon(Icons.settings_outlined), text: 'Settings'),
            ],
          ),
        ),
        body: AppBackground(
          child: TabBarView(
            children: [
              // Tab 1: Results (with filters)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tell RoadDogg what you need',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    // Structured filters (MVP): equipment + min $/mi
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _EquipmentFilter(
                          onChanged: (v) {
                            /* stored in state via callback; handled inline during _run */
                          },
                        ),
                        _MinRateFilter(
                          onChanged: (v) {
                            /* stored in state; see _run filters */
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textCtrl,
                      maxLength: 280,
                      decoration: const InputDecoration(
                        labelText:
                            'e.g., Flatbed, NJ → OH, ≤500 mi, deliver by Fri, avoid tolls',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _busy || _textCtrl.text.trim().isEmpty
                              ? null
                              : _run,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Find matching loads'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _textCtrl.clear();
                                  _results = const [];
                                }),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                        const Spacer(),
                        if (!isPremium)
                          Text(
                            'You have ${(3 - _weeklyUsed).clamp(0, 3)} of 3 RoadDogg searches left this week.',
                            style: TextStyle(color: Colors.amber.shade200),
                          ),
                        if (!isPremium && _textCtrl.text.trim().isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Text(
                              'Give RoadDogg a sentence or pick a few filters.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Text(
                              'Top matches for you',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            if (!isPremium)
                              const Text(
                                '• Showing top 3 suggestions • Upgrade for unlimited',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _busy && _results.isEmpty
                          ? const _LoadingState()
                          : (_results.isEmpty
                                ? const _EmptyState()
                                : ListView.builder(
                                    itemCount: _results.length,
                                    itemBuilder: (context, i) =>
                                        _SuggestionCard(
                                          s: _results[i],
                                          isPremium: isPremium,
                                          requestedIds: _requestedIds,
                                          onRequested: (id) {
                                            setState(
                                              () => _requestedIds.add(id),
                                            );
                                          },
                                        ),
                                  )),
                    ),
                  ],
                ),
              ),
              // Tab 2: My Loads (placeholder; to be wired next)
              const _MyLoadsTab(),
              // Tab 3: Settings (placeholder; to be wired next)
              const _SettingsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Sniffing out the best loads…'),
          SizedBox(height: 4),
          Text(
            'We’re sorting by profit per mile, deadhead distance, and fit.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48),
          const SizedBox(height: 8),
          const Text('No exact matches right now.'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {},
                child: const Text('Relax filters'),
              ),
              OutlinedButton(onPressed: () {}, child: const Text('Try again')),
            ],
          ),
        ],
      ),
    );
  }
}

class _EquipmentFilter extends StatefulWidget {
  final ValueChanged<String?> onChanged;
  const _EquipmentFilter({required this.onChanged});
  @override
  State<_EquipmentFilter> createState() => _EquipmentFilterState();
}

class _EquipmentFilterState extends State<_EquipmentFilter> {
  String? _equip;
  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      hint: const Text('Equipment'),
      value: _equip,
      items: const [
        DropdownMenuItem(value: 'Dry Van', child: Text('Dry Van')),
        DropdownMenuItem(value: 'Flatbed', child: Text('Flatbed')),
        DropdownMenuItem(value: 'Reefer', child: Text('Reefer')),
        DropdownMenuItem(value: 'Step Deck', child: Text('Step Deck')),
      ],
      onChanged: (v) {
        setState(() => _equip = v);
        widget.onChanged(v);
      },
    );
  }
}

class _MinRateFilter extends StatefulWidget {
  final ValueChanged<double?> onChanged;
  const _MinRateFilter({required this.onChanged});
  @override
  State<_MinRateFilter> createState() => _MinRateFilterState();
}

class _MinRateFilterState extends State<_MinRateFilter> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          labelText: r'Min $ / mi',
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        onChanged: (v) {
          widget.onChanged(double.tryParse(v));
        },
      ),
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  final RoadDoggSuggestion s;
  final bool isPremium;
  final ValueChanged<String>? onRequested;
  final Set<String> requestedIds;
  const _SuggestionCard({
    required this.s,
    required this.isPremium,
    this.onRequested,
    required this.requestedIds,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = s.load;
    final cpmStr = s.estimatedCpm == null
        ? 'Rate on request'
        : '\$${s.estimatedCpm!.toStringAsFixed(2)}/mi';
    final deadheadStr = s.estimatedDeadheadMiles == null
        ? '—'
        : '${s.estimatedDeadheadMiles} mi';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${load.origin} → ${load.destination}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Pickup',
                  value: load.pickupAt.toLocal().toString(),
                ),
                _MetricChip(label: 'Rate/CPM', value: cpmStr),
                _MetricChip(label: 'Deadhead', value: deadheadStr),
              ],
            ),
            const SizedBox(height: 6),
            Text(s.aiNote),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: requestedIds.contains(s.load.id)
                      ? null
                      : () async {
                          // Apply/Request Modal with template message and free cap check
                          final ctrl = ref.read(
                            ownerOpFreeCapsProvider.notifier,
                          );
                          if (!ctrl.canAcceptLoad(isPremium: isPremium)) {
                            debugPrint(
                              '[ANALYTICS] roaddogg_free_limit_hit type=bookings',
                            );
                            if (!context.mounted) return;
                            await showDialog(
                              context: context,
                              builder: (_) => const _UpgradeDialog(),
                            );
                            return;
                          }
                          final messageCtrl = TextEditingController(
                            text:
                                'Hi Broker, I can take this load on ${load.pickupAt.toLocal()}. Please confirm. Thanks — Me.',
                          );
                          final sent =
                              await showDialog<bool>(
                                context: context,
                                builder: (ctx) {
                                  return AlertDialog(
                                    title: const Text('Apply/Request Load'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Load #${load.id.substring(0, 6)}',
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${load.origin} → ${load.destination} • Pickup ${load.pickupAt.toLocal()}',
                                          ),
                                          const SizedBox(height: 8),
                                          Text(cpmStr),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: messageCtrl,
                                            maxLines: 4,
                                            decoration: const InputDecoration(
                                              labelText: 'Message to broker',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Send Request'),
                                      ),
                                    ],
                                  );
                                },
                              ) ??
                              false;
                          if (!sent) return;
                          try {
                            await ref
                                .read(roadDoggServiceProvider)
                                .sendRequest(
                                  loadId: s.load.id,
                                  message: messageCtrl.text,
                                );
                            ctrl.recordLoadAccepted();
                            onRequested?.call(s.load.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Request sent to broker.'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.send),
                  label: Text(
                    requestedIds.contains(s.load.id)
                        ? 'Requested'
                        : 'Request/Apply',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved for later (MVP).')),
                    );
                  },
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Save for later'),
                ),
                const Spacer(),
                if (isPremium)
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Compare'),
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.lock, size: 16),
                      SizedBox(width: 4),
                      Text('Upgrade to compare'),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MyLoadsTab extends ConsumerWidget {
  const _MyLoadsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(roadDoggServiceProvider).listMyRequests(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final items = snap.data as List<BrokerRequestItem>;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 48),
                  SizedBox(height: 8),
                  Text('No requests yet.'),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final it = items[i];
            final statusColor = it.status == 'approved'
                ? Colors.green
                : it.status == 'rejected'
                ? Colors.red
                : Colors.amber;
            return ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text('Load #${it.loadId.substring(0, 6)} — ${it.status}'),
              subtitle: Text(it.message ?? ''),
              trailing: Chip(
                label: Text(it.status),
                backgroundColor: statusColor.withValues(alpha: 0.15),
              ),
            );
          },
        );
      },
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(ownerOpFreeCapsProvider);
    final remainingSearches = (3 - caps.roaddoggUsesThisWeek).clamp(0, 3);
    final remainingBookings = (3 - caps.loadsAcceptedThisMonth).clamp(0, 3);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(
          leading: Icon(Icons.local_shipping_outlined),
          title: Text('Default equipment'),
          subtitle: Text('Choose in a future update'),
        ),
        const ListTile(
          leading: Icon(Icons.home_work_outlined),
          title: Text('Preferred region / home base'),
          subtitle: Text('Set in a future update'),
        ),
        const ListTile(
          leading: Icon(Icons.route_outlined),
          title: Text('Max deadhead'),
          subtitle: Text('Set in a future update'),
        ),
        const ListTile(
          leading: Icon(Icons.attach_money_outlined),
          title: Text('Minimum rate per mile'),
          subtitle: Text('Set in a future update'),
        ),
        const ListTile(
          leading: Icon(Icons.notifications_outlined),
          title: Text('Notifications'),
          subtitle: Text('Enable alerts in a future update'),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.speed_outlined),
          title: const Text('Free tier meter'),
          subtitle: Text(
            'This week: ${3 - remainingSearches}/3 searches used • This month: ${3 - remainingBookings}/3 bookings used',
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _UpgradeDialog extends StatelessWidget {
  const _UpgradeDialog();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unlock unlimited RoadDogg matching'),
      content: const Text(
        'Upgrade to Owner-Op Pro (\$9.99/mo) for unlimited suggestions and load board access.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Maybe later'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Upgrade'),
        ),
      ],
    );
  }
}
