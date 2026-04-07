import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../common/services/truck_stop_services.dart';

class DealEditor extends ConsumerStatefulWidget {
  final String stopId;
  final TruckStopDeal? initial;
  final String tier; // 'free' | 'pro' | 'enterprise'
  const DealEditor({
    super.key,
    required this.stopId,
    this.initial,
    required this.tier,
  });

  @override
  ConsumerState<DealEditor> createState() => _DealEditorState();
}

class _DealEditorState extends ConsumerState<DealEditor> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _validUntil;
  bool _active = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d != null) {
      _titleCtrl.text = d.title;
      _descCtrl.text = d.description ?? '';
      _validUntil = d.validUntil;
      _active = d.isActive;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: _validUntil ?? now,
    );
    if (date != null) {
      setState(() {
        _validUntil = DateTime(date.year, date.month, date.day);
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final svc = ref.read(truckStopServiceProvider);
      final deal = await svc.upsertDeal(
        id: widget.initial?.id,
        truckStopId: widget.stopId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        validUntil: _validUntil,
        isActive: _active,
      );
      if (mounted) Navigator.of(context).pop(deal);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final isFree = widget.tier == 'free';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              isEdit ? 'Edit Deal' : 'New Deal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text('Title'),
            TextField(controller: _titleCtrl),
            const SizedBox(height: 12),
            const Text('Description'),
            TextField(controller: _descCtrl, maxLines: 3),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Active'),
                const SizedBox(width: 12),
                Switch(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                if (isFree)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      '(Free tier: max 2 active)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Valid until'),
                const SizedBox(width: 12),
                Text(
                  _validUntil == null
                      ? 'None'
                      : _validUntil!.toLocal().toString().split(' ').first,
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Pick date'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
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
                label: Text(isEdit ? 'Save Changes' : 'Create Deal'),
                onPressed: _busy ? null : _save,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
