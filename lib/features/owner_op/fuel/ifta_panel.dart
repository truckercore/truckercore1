import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class FuelPurchaseInput {
  final double gallons;
  final double pricePerGallon;
  final String location;
  final DateTime at;
  const FuelPurchaseInput({
    required this.gallons,
    required this.pricePerGallon,
    required this.location,
    required this.at,
  });
}

class FuelIftaPanel extends ConsumerStatefulWidget {
  const FuelIftaPanel({super.key});
  @override
  ConsumerState<FuelIftaPanel> createState() => _FuelIftaPanelState();
}

class _FuelIftaPanelState extends ConsumerState<FuelIftaPanel> {
  final _gallons = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  String? _lastMsg;
  List<FuelPurchaseInput> _recent = const [];

  Future<void> _save() async {
    final gal = double.tryParse(_gallons.text.trim()) ?? 0;
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final loc = _location.text.trim();
    if (gal <= 0 || price <= 0 || loc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter gallons, price, and location')),
      );
      return;
    }
    final item = FuelPurchaseInput(
      gallons: gal,
      pricePerGallon: price,
      location: loc,
      at: DateTime.now().toUtc(),
    );
    try {
      final cfg = ref.read(appConfigProvider);
      final ready =
          cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
      if (ready) {
        await Supabase.instance.client.from('fuel_purchases').insert({
          'gallons': gal,
          'price_per_gallon': price,
          'location': loc,
          'purchased_at': item.at.toIso8601String(),
        });
      }
      setState(() {
        _recent = [item, ..._recent].take(5).toList();
        _lastMsg =
            'Saved ${gal.toStringAsFixed(2)} gal @ \$${price.toStringAsFixed(2)}';
      });
    } catch (_) {
      setState(() {
        _recent = [item, ..._recent].take(5).toList();
        _lastMsg = 'Saved locally (offline)';
      });
    }
    _gallons.clear();
    _price.clear();
    _location.clear();
  }

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now();
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    final totalGal = _recent.fold<double>(0, (a, e) => a + e.gallons);
    final totalCost = _recent.fold<double>(
      0,
      (a, e) => a + e.gallons * e.pricePerGallon,
    );
    final avgPrice = totalGal == 0 ? 0 : totalCost / totalGal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_gas_station_outlined),
                SizedBox(width: 8),
                Text(
                  'Fuel / IFTA Panel',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _gallons,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Gallons',
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price \$/gal',
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _location,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'City, ST',
                      isDense: true,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Add'),
                ),
                if (_lastMsg != null) Chip(label: Text(_lastMsg!)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Monthly IFTA summary ($monthStr)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                Chip(label: Text('Gallons: ${totalGal.toStringAsFixed(2)}')),
                Chip(label: Text('Avg \$/gal: ${avgPrice.toStringAsFixed(2)}')),
                Chip(
                  label: Text('Total Cost: \$${totalCost.toStringAsFixed(2)}'),
                ),
              ],
            ),
            if (_recent.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Recent'),
              ..._recent.map(
                (e) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_gas_station),
                  title: Text(
                    '${e.gallons.toStringAsFixed(2)} gal @ \$${e.pricePerGallon.toStringAsFixed(2)}',
                  ),
                  subtitle: Text('${e.location} • ${e.at.toLocal()}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
