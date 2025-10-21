import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/services/loads_service.dart';
import 'free_caps.dart';

class LoadFormSheet extends ConsumerStatefulWidget {
  const LoadFormSheet({super.key});

  @override
  ConsumerState<LoadFormSheet> createState() => _LoadFormSheetState();
}

class _LoadFormSheetState extends ConsumerState<LoadFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _rpmCtrl = TextEditingController();
  final _milesCtrl = TextEditingController();
  String _equipment = 'dry_van';
  DateTime? _pickup;
  DateTime? _dropoff;
  bool _busy = false;

  Future<void> _pickDate(bool isPickup) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: (isPickup ? _pickup : _dropoff) ?? now,
    );
    if (date != null) {
      setState(() {
        if (isPickup) {
          _pickup = date;
        } else {
          _dropoff = date;
        }
      });
    }
  }

  Future<void> _save() async {
    // Capture context-dependent objects before awaits
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // Enforce Free cap: 20 active loads
    final isAllowed = await canCreateAnotherLoad(ref);
    if (!isAllowed) {
      messenger.showSnackBar(
        SnackBar(content: Text(FreeLoadCaps.reachedMessage())),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_pickup == null || _dropoff == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Select pickup and dropoff dates')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final svc = ref.read(loadsServiceProvider);
      final created = await svc.createLoad(
        origin: _originCtrl.text.trim(),
        destination: _destCtrl.text.trim(),
        pickupAt: _pickup!,
        dropoffAt: _dropoff!,
        vehicleType: _equipment,
        postedRateUsdPerMi: double.tryParse(_rpmCtrl.text.trim()),
        estimatedMiles: int.tryParse(_milesCtrl.text.trim()),
      );
      navigator.pop(created);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to create: $e')));
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
            key: _formKey,
            child: Column(
              children: [
                const Text(
                  'New Load',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _originCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Origin',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _destCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _equipment,
                        items: const [
                          DropdownMenuItem(
                            value: 'dry_van',
                            child: Text('Dry Van'),
                          ),
                          DropdownMenuItem(
                            value: 'reefer',
                            child: Text('Reefer'),
                          ),
                          DropdownMenuItem(
                            value: 'flatbed',
                            child: Text('Flatbed'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _equipment = v ?? _equipment),
                        decoration: const InputDecoration(
                          labelText: 'Equipment Type',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        controller: _rpmCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Rate \$/mi',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: TextFormField(
                        controller: _milesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Est. miles',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _pickup == null
                            ? 'Pickup: —'
                            : 'Pickup: ${_pickup!.toLocal()}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.date_range),
                      label: const Text('Select'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dropoff == null
                            ? 'Dropoff: —'
                            : 'Dropoff: ${_dropoff!.toLocal()}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.date_range),
                      label: const Text('Select'),
                    ),
                  ],
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
                    label: const Text('Create'),
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
