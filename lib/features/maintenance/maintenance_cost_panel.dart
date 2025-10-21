import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/maintenace_service.dart';

class MaintenanceCostPanel extends ConsumerStatefulWidget {
  const MaintenanceCostPanel({super.key});

  @override
  ConsumerState<MaintenanceCostPanel> createState() =>
      _MaintenanceCostPanelState();
}

class _MaintenanceCostPanelState extends ConsumerState<MaintenanceCostPanel> {
  bool _loading = false;
  List<MaintenanceSummary> _items = const [];
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
      final svc = ref.read(maintenanceServiceProvider);
      _items = await svc.topHighCost();
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
        child: Text('No maintenance data available.'),
      );
    }

    return Column(
      children: [
        ..._items.map(
          (m) => Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: Icon(
                m.suggestion == 'Replace Soon'
                    ? Icons.warning_amber
                    : m.suggestion == 'Repair'
                    ? Icons.build_circle_outlined
                    : Icons.visibility_outlined,
                color: m.suggestion == 'Replace Soon'
                    ? Colors.amber
                    : m.suggestion == 'Repair'
                    ? Colors.blueGrey
                    : Colors.green,
              ),
              title: Text('${m.truckId} • ${m.suggestion}'),
              subtitle: Text(
                'Events: ${m.events} • Last 90d: \$${(m.last90DaysCents / 100).toStringAsFixed(0)} • Lifetime: \$${(m.totalCostCents / 100).toStringAsFixed(0)} • Age: ${m.ageYears}y${m.underWarranty ? ' • Warranty' : ''}\n${m.rationale}',
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Open maintenance history coming soon'),
                    ),
                  );
                },
                child: const Text('Details'),
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
}
