import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../common/services/truck_stop_services.dart';
import 'deal_editor.dart';

final currentPartnerStopIdProvider = StateProvider<String?>((_) => null);

class PartnerDealsScreen extends ConsumerStatefulWidget {
  const PartnerDealsScreen({super.key});

  @override
  ConsumerState<PartnerDealsScreen> createState() => _PartnerDealsScreenState();
}

class _PartnerDealsScreenState extends ConsumerState<PartnerDealsScreen> {
  bool _loading = false;
  List<TruckStop> _stops = const [];
  List<TruckStopDeal> _deals = const [];
  String _tier = 'free';

  @override
  void initState() {
    super.initState();
    _loadStopsThenDeals();
  }

  Future<void> _loadStopsThenDeals() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(truckStopServiceProvider);
      // Only show stops the operator manages
      _stops = await svc.fetchOperatorStops();
      final selected = ref.read(currentPartnerStopIdProvider);
      if (selected == null && _stops.isNotEmpty) {
        ref.read(currentPartnerStopIdProvider.notifier).state = _stops.first.id;
      }
      await _loadDeals();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDeals() async {
    final svc = ref.read(truckStopServiceProvider);
    final stopId = ref.read(currentPartnerStopIdProvider);
    if (stopId == null) {
      setState(() {
        _deals = const [];
        _tier = 'free';
      });
      return;
    }
    final results = await Future.wait([
      svc.fetchDealsForStop(stopId),
      svc.getStopTier(stopId),
    ]);
    setState(() {
      _deals = results[0] as List<TruckStopDeal>;
      _tier = results[1] as String;
    });
  }

  Future<void> _editDeal({TruckStopDeal? deal}) async {
    final stopId = ref.read(currentPartnerStopIdProvider);
    if (stopId == null) return;
    final updated = await showModalBottomSheet<TruckStopDeal>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DealEditor(stopId: stopId, initial: deal, tier: _tier),
    );
    if (updated != null) {
      await _loadDeals();
    }
  }

  Future<void> _deleteDeal(String id) async {
    final svc = ref.read(truckStopServiceProvider);
    await svc.deleteDeal(id);
    await _loadDeals();
  }

  @override
  Widget build(BuildContext context) {
    final stopId = ref.watch(currentPartnerStopIdProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner: Deals'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadDeals,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Truck Stop:'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String?>(
                    value: _stops.any((s) => s.id == stopId) ? stopId : null,
                    isExpanded: true,
                    hint: const Text('Select a truck stop'),
                    items: _stops
                        .map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      ref.read(currentPartnerStopIdProvider.notifier).state = v;
                      await _loadDeals();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Tier: ${_tier.toUpperCase()}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _deals.isEmpty
                  ? const Center(
                      child: Text('No deals yet. Tap + to create one.'),
                    )
                  : ListView.separated(
                      itemCount: _deals.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final d = _deals[i];
                        return ListTile(
                          leading: Icon(
                            d.isActive
                                ? Icons.local_offer
                                : Icons.local_offer_outlined,
                            color: d.isActive ? Colors.green : null,
                          ),
                          title: Text(d.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (d.description != null &&
                                  d.description!.isNotEmpty)
                                Text(d.description!),
                              if (d.validUntil != null)
                                Text('Valid until: ${d.validUntil!.toLocal()}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editDeal(deal: d),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteDeal(d.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_partner_deal_add',
        icon: const Icon(Icons.add),
        label: const Text('New Deal'),
        onPressed: () => _editDeal(),
      ),
    );
  }
}
