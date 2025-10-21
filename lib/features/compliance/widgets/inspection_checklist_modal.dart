import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InspectionChecklistModal extends StatefulWidget {
  final bool preTrip;
  const InspectionChecklistModal({super.key, required this.preTrip});

  @override
  State<InspectionChecklistModal> createState() =>
      _InspectionChecklistModalState();
}

class _InspectionChecklistModalState extends State<InspectionChecklistModal> {
  final items = <String, bool>{
    'Lights & Reflectors': false,
    'Brakes': false,
    'Tires': false,
    'Coupling Devices': false,
    'Emergency Equipment': false,
  };
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('dispatch_events').insert({
        'event_type': widget.preTrip ? 'pretrip_check' : 'posttrip_check',
        'details': {
          'items': items.entries
              .map((e) => {'name': e.key, 'ok': e.value})
              .toList(),
          'ts': DateTime.now().toUtc().toIso8601String(),
        },
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.preTrip ? 'Pre-Trip Inspection' : 'Post-Trip Inspection',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...items.keys.map(
              (k) => CheckboxListTile(
                value: items[k],
                onChanged: (v) => setState(() => items[k] = v ?? false),
                title: Text(k),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
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
    );
  }
}
