import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../terminals/services/terminal_service.dart';
import 'services/trucks_service.dart';

class TrucksAdminScreen extends ConsumerStatefulWidget {
  const TrucksAdminScreen({super.key});

  @override
  ConsumerState<TrucksAdminScreen> createState() => _TrucksAdminScreenState();
}

class _TrucksAdminScreenState extends ConsumerState<TrucksAdminScreen> {
  bool _loading = false;
  String? _error;
  List<Truck> _rows = const [];

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
      final term = ref.read(selectedTerminalIdProvider);
      _rows = await ref.read(trucksServiceProvider).list(terminalCode: term);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveRow(_TruckEdit m) async {
    try {
      await ref
          .read(trucksServiceProvider)
          .updateTruck(
            id: m.id,
            status: m.status,
            terminalCode: m.terminalCode,
            lat: m.lat,
            lng: m.lng,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Truck updated')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final termsAsync = ref.watch(terminalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trucks Admin'),
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
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final t = _rows[i];
                  final model = _TruckEdit.fromTruck(t);
                  return _TruckEditorRow(
                    model: model,
                    terminals: termsAsync,
                    onSave: _saveRow,
                  );
                },
              ),
            ),
    );
  }
}

class _TruckEdit {
  final String id;
  final String labelOrCode;
  String? terminalCode;
  String status;
  double? lat;
  double? lng;

  _TruckEdit({
    required this.id,
    required this.labelOrCode,
    required this.terminalCode,
    required this.status,
    required this.lat,
    required this.lng,
  });

  factory _TruckEdit.fromTruck(Truck t) => _TruckEdit(
    id: t.id,
    labelOrCode: t.label, // if your schema uses code, swap to t.code
    terminalCode: t.terminalCode,
    status: t.status,
    lat: t.lat,
    lng: t.lng,
  );
}

class _TruckEditorRow extends StatefulWidget {
  final _TruckEdit model;
  final List<Terminal> terminals;
  final Future<void> Function(_TruckEdit) onSave;

  const _TruckEditorRow({
    required this.model,
    required this.terminals,
    required this.onSave,
  });

  @override
  State<_TruckEditorRow> createState() => _TruckEditorRowState();
}

class _TruckEditorRowState extends State<_TruckEditorRow> {
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late String _status;
  String? _terminal;

  @override
  void initState() {
    super.initState();
    _status = widget.model.status;
    _terminal = widget.model.terminalCode;
    _latCtrl = TextEditingController(
      text: widget.model.lat?.toStringAsFixed(6) ?? '',
    );
    _lngCtrl = TextEditingController(
      text: widget.model.lng?.toStringAsFixed(6) ?? '',
    );
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.model.labelOrCode,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'moving', child: Text('moving')),
                    DropdownMenuItem(value: 'idle', child: Text('idle')),
                    DropdownMenuItem(value: 'offline', child: Text('offline')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _terminal,
                    items: [
                      const DropdownMenuItem<String?>(
                        child: Text('No terminal'),
                      ),
                      ...widget.terminals.map(
                        (t) => DropdownMenuItem<String?>(
                          value: t.id,
                          child: Text(t.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _terminal = v),
                    decoration: const InputDecoration(
                      labelText: 'Terminal',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Lat',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Lng',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: () {
                    final lat = double.tryParse(_latCtrl.text.trim());
                    final lng = double.tryParse(_lngCtrl.text.trim());
                    final copy = _TruckEdit(
                      id: widget.model.id,
                      labelOrCode: widget.model.labelOrCode,
                      terminalCode: _terminal,
                      status: _status,
                      lat: lat,
                      lng: lng,
                    );
                    widget.onSave(copy);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
