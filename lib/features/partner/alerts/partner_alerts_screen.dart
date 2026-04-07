import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/services/truck_stop_services.dart';

final partnerAlertsCurrentStopIdProvider = StateProvider<String?>((_) => null);

class PartnerAlertsScreen extends ConsumerStatefulWidget {
  const PartnerAlertsScreen({super.key});

  @override
  ConsumerState<PartnerAlertsScreen> createState() =>
      _PartnerAlertsScreenState();
}

class _PartnerAlertsScreenState extends ConsumerState<PartnerAlertsScreen> {
  bool _loading = false;
  List<TruckStop> _stops = const [];
  List<TruckStopAlert> _recent = const [];
  String? _error;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _severity = 'info';

  @override
  void initState() {
    super.initState();
    _loadStopsAndAlerts();
  }

  Future<void> _loadStopsAndAlerts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(truckStopServiceProvider);
      _stops = await svc.fetchTruckStops();
      final current = ref.read(partnerAlertsCurrentStopIdProvider);
      if (current == null && _stops.isNotEmpty) {
        ref.read(partnerAlertsCurrentStopIdProvider.notifier).state =
            _stops.first.id;
      }
      await _refreshAlerts();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAlerts() async {
    final stopId = ref.read(partnerAlertsCurrentStopIdProvider);
    if (stopId == null) return;
    final svc = ref.read(truckStopServiceProvider);
    final rows = await svc.fetchRecentAlerts(stopId);
    setState(() => _recent = rows);
  }

  Future<void> _sendQuick(String preset) async {
    final stopId = ref.read(partnerAlertsCurrentStopIdProvider);
    if (stopId == null) return;
    final svc = ref.read(truckStopServiceProvider);

    String title, body, severity = 'info';
    switch (preset) {
      case 'full':
        title = 'Lot Full';
        body = 'Parking lot is currently full.';
        severity = 'warning';
        break;
      case 'reopen':
        title = 'Lot Reopening';
        body = 'Parking will reopen within 1 hour.';
        severity = 'info';
        break;
      default:
        title = 'Notice';
        body = 'Update from the truck stop.';
    }

    await svc.sendAlert(
      truckStopId: stopId,
      title: title,
      body: body,
      severity: severity,
    );
    await _refreshAlerts();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert sent')));
    }
  }

  Future<void> _sendCustom() async {
    final stopId = ref.read(partnerAlertsCurrentStopIdProvider);
    if (stopId == null) return;
    final svc = ref.read(truckStopServiceProvider);
    await svc.sendAlert(
      truckStopId: stopId,
      title: _titleCtrl.text.trim().isEmpty ? 'Notice' : _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      severity: _severity,
    );
    _titleCtrl.clear();
    _bodyCtrl.clear();
    setState(() => _severity = 'info');
    await _refreshAlerts();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert sent')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopId = ref.watch(partnerAlertsCurrentStopIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner: Alerts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refreshAlerts,
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
                      ref
                              .read(partnerAlertsCurrentStopIdProvider.notifier)
                              .state =
                          v;
                      await _refreshAlerts();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.block),
                      label: const Text('Lot Full'),
                      onPressed: () => _sendQuick('full'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.timer),
                      label: const Text('Reopening in 1h'),
                      onPressed: () => _sendQuick('reopen'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Custom Alert',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Title'),
                    ),
                    TextField(controller: _titleCtrl),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Body (optional)'),
                    ),
                    TextField(controller: _bodyCtrl, maxLines: 3),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Severity:'),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _severity,
                          items: const [
                            DropdownMenuItem(
                              value: 'info',
                              child: Text('Info'),
                            ),
                            DropdownMenuItem(
                              value: 'warning',
                              child: Text('Warning'),
                            ),
                            DropdownMenuItem(
                              value: 'critical',
                              child: Text('Critical'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _severity = v ?? 'info'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          label: const Text('Send'),
                          onPressed: _sendCustom,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _recent.isEmpty
                  ? const Center(child: Text('No alerts yet'))
                  : ListView.separated(
                      itemCount: _recent.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final a = _recent[i];
                        IconData ic;
                        Color? color;
                        switch (a.severity) {
                          case 'warning':
                            ic = Icons.warning_amber;
                            color = Colors.amber;
                            break;
                          case 'critical':
                            ic = Icons.error_outline;
                            color = Colors.red;
                            break;
                          default:
                            ic = Icons.info_outline;
                            color = null;
                        }
                        return ListTile(
                          leading: Icon(ic, color: color),
                          title: Text(a.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (a.body != null && a.body!.isNotEmpty)
                                Text(a.body!),
                              Text(a.createdAt.toLocal().toString()),
                            ],
                          ),
                        );
                      },
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
