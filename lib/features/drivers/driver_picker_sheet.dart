import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../terminals/services/terminal_service.dart';
import 'services/drivers_service.dart';

class DriverPickerSheet extends ConsumerStatefulWidget {
  const DriverPickerSheet({super.key});

  @override
  ConsumerState<DriverPickerSheet> createState() => _DriverPickerSheetState();
}

class _DriverPickerSheetState extends ConsumerState<DriverPickerSheet> {
  bool _loading = false;
  String? _error;
  List<Driver> _rows = const [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(driversServiceProvider);
      final term = ref.read(selectedTerminalIdProvider);
      _rows = await svc.list(terminalCode: term, q: _searchCtrl.text);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'driving':
        return Colors.green;
      case 'resting':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Select Driver')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search drivers',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _search,
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Flexible(
              child: _rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No drivers found'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _rows.length,
                      itemBuilder: (context, i) {
                        final d = _rows[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(
                              d.status,
                            ).withAlpha(38),
                            child: Icon(
                              Icons.person,
                              color: _statusColor(d.status),
                            ),
                          ),
                          title: Text(d.name),
                          subtitle: Text(
                            '${d.email ?? ''}${d.email != null && d.phone != null ? ' • ' : ''}${d.phone ?? ''}\nStatus: ${d.status} • HOS: ${d.hosHoursLeft.toStringAsFixed(1)}h',
                          ),
                          isThreeLine: true,
                          onTap: () => Navigator.of(context).pop(d),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
