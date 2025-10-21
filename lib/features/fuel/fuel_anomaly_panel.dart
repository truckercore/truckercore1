import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/fuel_service.dart';

class FuelAnomalyPanel extends ConsumerStatefulWidget {
  const FuelAnomalyPanel({super.key});

  @override
  ConsumerState<FuelAnomalyPanel> createState() => _FuelAnomalyPanelState();
}

class _FuelAnomalyPanelState extends ConsumerState<FuelAnomalyPanel> {
  bool _loading = false;
  List<FuelAnomaly> _items = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(fuelServiceProvider);
      _items = await svc.detect();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Error: $_error'),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No fuel anomalies detected.'),
      );
    }

    return Column(
      children: [
        ..._items.map(
          (a) => Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: _iconFor(a.type, a.severity),
              title: Text('${a.truckId} • ${_labelFor(a.type)}'),
              subtitle: Text('${a.summary}\n${a.detail}'),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Open fuel report coming soon'),
                    ),
                  );
                },
                child: const Text('Investigate'),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Recompute'),
          ),
        ),
      ],
    );
  }

  Widget _iconFor(String type, double severity) {
    IconData icon;
    Color color;
    switch (type) {
      case 'siphon_suspected':
        icon = Icons.local_gas_station_outlined;
        color = Colors.redAccent;
        break;
      case 'mpg_outlier':
        icon = Icons.bar_chart_outlined;
        color = Colors.orange;
        break;
      default:
        icon = Icons.report_gmailerrorred_outlined;
        color = Colors.amber;
    }
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }

  String _labelFor(String type) {
    switch (type) {
      case 'siphon_suspected':
        return 'Fuel Siphoning Suspected';
      case 'mpg_outlier':
        return 'MPG Outlier';
      case 'over_report':
        return 'Over-reporting Suspected';
      default:
        return 'Fuel Anomaly';
    }
  }
}
