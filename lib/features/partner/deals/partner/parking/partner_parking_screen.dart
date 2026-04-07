import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../common/services/truck_stop_services.dart';
import 'parking_control.dart';

final partnerCurrentStopIdProvider = StateProvider<String?>((_) => null);

class PartnerParkingScreen extends ConsumerStatefulWidget {
  const PartnerParkingScreen({super.key});

  @override
  ConsumerState<PartnerParkingScreen> createState() =>
      _PartnerParkingScreenState();
}

class _PartnerParkingScreenState extends ConsumerState<PartnerParkingScreen> {
  bool _loading = false;
  List<TruckStop> _stops = const [];
  TruckStopParking? _latest;
  String _tier = 'free';

  // inputs for baseline save
  final _totalCtrl = TextEditingController();
  final _availCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStopsAndData();
  }

  Future<void> _loadStopsAndData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(truckStopServiceProvider);
      // Only operator-authorized stops
      _stops = await svc.fetchOperatorStops();
      final current = ref.read(partnerCurrentStopIdProvider);
      if (current == null && _stops.isNotEmpty) {
        ref.read(partnerCurrentStopIdProvider.notifier).state = _stops.first.id;
      }
      await _loadData();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadData() async {
    final stopId = ref.read(partnerCurrentStopIdProvider);
    if (stopId == null) {
      setState(() {
        _latest = null;
        _tier = 'free';
      });
      return;
    }
    final svc = ref.read(truckStopServiceProvider);
    final latest = await svc.latestParkingFor(stopId);
    final tier = await svc.getStopTier(stopId);
    setState(() {
      _latest = latest;
      _tier = tier;
      _totalCtrl.text = (latest?.totalSpots ?? 0).toString();
      _availCtrl.text = (latest?.availableSpots ?? 0).toString();
    });
  }

  Future<void> _saveBaseline() async {
    final stopId = ref.read(partnerCurrentStopIdProvider);
    if (stopId == null) return;
    final svc = ref.read(truckStopServiceProvider);
    final total = int.tryParse(_totalCtrl.text) ?? 0;
    final avail = int.tryParse(_availCtrl.text) ?? 0;
    try {
      await svc.updateParking(
        truckStopId: stopId,
        totalSpots: total,
        availableSpots: avail,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Baseline saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _nudge(int delta) async {
    final stopId = ref.read(partnerCurrentStopIdProvider);
    if (stopId == null) return;
    final svc = ref.read(truckStopServiceProvider);

    // Free tier: soft limit 4 updates/day
    if (_tier == 'free') {
      final ok = await svc.canFreeTierUpdate(stopId);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Free tier limit reached: 4 updates per day. Upgrade for live controls.',
              ),
            ),
          );
        }
        return;
      }
    }

    try {
      await svc.nudgeAvailability(truckStopId: stopId, delta: delta);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _lotFull() async {
    final stopId = ref.read(partnerCurrentStopIdProvider);
    if (stopId == null) return;
    final svc = ref.read(truckStopServiceProvider);

    if (_tier == 'free') {
      final ok = await svc.canFreeTierUpdate(stopId);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Free tier limit reached: 4 updates per day. Upgrade for live controls.',
              ),
            ),
          );
        }
        return;
      }
    }

    try {
      await svc.markLotFull(stopId);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopId = ref.watch(partnerCurrentStopIdProvider);
    final liveEnabled = _tier != 'free';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner: Parking'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
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
                      ref.read(partnerCurrentStopIdProvider.notifier).state = v;
                      await _loadData();
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Total spots'),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _totalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text('Available'),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _availCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ParkingControls(
                      totalSpots:
                          int.tryParse(_totalCtrl.text) ??
                          (_latest?.totalSpots ?? 0),
                      availableSpots:
                          int.tryParse(_availCtrl.text) ??
                          (_latest?.availableSpots ?? 0),
                      liveEnabled: liveEnabled,
                      onSaveBaseline: _saveBaseline,
                      onPlusOne: () => _nudge(1),
                      onMinusOne: () => _nudge(-1),
                      onLotFull: _lotFull,
                    ),
                    if (_latest != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Current: ${_latest!.availableSpots}/${_latest!.totalSpots} (updated ${_latest!.updatedAt == null ? 'n/a' : _latest!.updatedAt!.toLocal()})',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
