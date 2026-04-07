import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/services/loads_service.dart';

class EditLoadFinancialsSheet extends ConsumerStatefulWidget {
  final String loadId;
  final int revenueCents;
  final int fuelCents;
  final int tollsCents;
  final int maintenanceCents;
  final int wageCents;

  const EditLoadFinancialsSheet({
    super.key,
    required this.loadId,
    required this.revenueCents,
    required this.fuelCents,
    required this.tollsCents,
    required this.maintenanceCents,
    required this.wageCents,
  });

  @override
  ConsumerState<EditLoadFinancialsSheet> createState() =>
      _EditLoadFinancialsSheetState();
}

class _EditLoadFinancialsSheetState
    extends ConsumerState<EditLoadFinancialsSheet> {
  final _form = GlobalKey<FormState>();
  final _revCtrl = TextEditingController();
  final _fuelCtrl = TextEditingController();
  final _tollsCtrl = TextEditingController();
  final _maintCtrl = TextEditingController();
  final _wageCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _revCtrl.text = widget.revenueCents.toString();
    _fuelCtrl.text = widget.fuelCents.toString();
    _tollsCtrl.text = widget.tollsCents.toString();
    _maintCtrl.text = widget.maintenanceCents.toString();
    _wageCtrl.text = widget.wageCents.toString();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      int parseCents(String s) => int.tryParse(s.trim()) ?? 0;
      await ref
          .read(loadsServiceProvider)
          .updateFinancials(
            loadId: widget.loadId,
            revenueCents: parseCents(_revCtrl.text),
            fuelCents: parseCents(_fuelCtrl.text),
            tollsCents: parseCents(_tollsCtrl.text),
            maintenanceCents: parseCents(_maintCtrl.text),
            wageCents: parseCents(_wageCtrl.text),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
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
                  'Edit Load Financials',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _centsField(controller: _revCtrl, label: 'Revenue (cents)'),
                const SizedBox(height: 8),
                _centsField(controller: _fuelCtrl, label: 'Fuel (cents)'),
                const SizedBox(height: 8),
                _centsField(controller: _tollsCtrl, label: 'Tolls (cents)'),
                const SizedBox(height: 8),
                _centsField(
                  controller: _maintCtrl,
                  label: 'Maintenance (cents)',
                ),
                const SizedBox(height: 8),
                _centsField(controller: _wageCtrl, label: 'Wages (cents)'),
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
                        : const Icon(Icons.save),
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

  Widget _centsField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) =>
          (int.tryParse(v?.trim() ?? '') ?? -1) >= 0 ? null : 'Enter >= 0',
    );
  }
}
