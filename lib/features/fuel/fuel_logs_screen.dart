import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/services/fuel_logs_service.dart';
import 'add_fuel_sheet.dart';

class FuelLogsScreen extends ConsumerStatefulWidget {
  const FuelLogsScreen({super.key});

  @override
  ConsumerState<FuelLogsScreen> createState() => _FuelLogsScreenState();
}

class _FuelLogsScreenState extends ConsumerState<FuelLogsScreen> {
  bool _loading = false;
  String? _error;
  List<FuelLog> _rows = const [];

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
      _rows = await ref.read(fuelLogsServiceProvider).list();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddFuelSheet(),
    );
    if (ok == true) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fuel log added')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _rows.isEmpty
          ? const Center(child: Text('No fuel logs yet. Tap + to add one.'))
          : ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = _rows[i];
                return ListTile(
                  leading: const Icon(Icons.local_gas_station_outlined),
                  title: Text(
                    '${r.truckId} • ${r.gallons.toStringAsFixed(2)} gal • \$${(r.priceCents / 100).toStringAsFixed(2)}',
                  ),
                  subtitle: Text(
                    '${r.ts.toLocal()}${r.location != null ? ' • ${r.location}' : ''}',
                  ),
                  trailing: Text(r.source),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_fuel_add',
        icon: const Icon(Icons.add),
        label: const Text('Add Fuel'),
        onPressed: _add,
      ),
    );
  }
}
