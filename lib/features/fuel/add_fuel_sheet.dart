import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/services/fuel_logs_service.dart';

class AddFuelSheet extends ConsumerStatefulWidget {
  const AddFuelSheet({super.key});

  @override
  ConsumerState<AddFuelSheet> createState() => _AddFuelSheetState();
}

class _AddFuelSheetState extends ConsumerState<AddFuelSheet> {
  final _form = GlobalKey<FormState>();
  final _truckCtrl = TextEditingController(text: 'TRK-2310');
  final _gallonsCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _odoCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _source = 'card';
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(fuelLogsServiceProvider)
          .add(
            truckId: _truckCtrl.text.trim(),
            gallons: double.tryParse(_gallonsCtrl.text.trim()),
            priceCents: int.tryParse(_priceCtrl.text.trim()),
            odometerKm: double.tryParse(_odoCtrl.text.trim()),
            location: _locCtrl.text.trim().isEmpty
                ? null
                : _locCtrl.text.trim(),
            source: _source,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Fuel',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _truckCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Truck ID',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _gallonsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Gallons',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0
                            ? null
                            : 'Enter gallons',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Price (cents)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v ?? '') ?? -1) >= 0
                            ? null
                            : 'Enter cents',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _odoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Odometer (km)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _source,
                  items: const [
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'manual', child: Text('Manual')),
                    DropdownMenuItem(value: 'import', child: Text('Import')),
                  ],
                  onChanged: (v) => setState(() => _source = v ?? 'card'),
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
