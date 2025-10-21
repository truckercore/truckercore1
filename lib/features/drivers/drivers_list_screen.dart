import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../terminals/services/terminal_service.dart';
import 'services/drivers_service.dart';

class DriversListScreen extends ConsumerStatefulWidget {
  const DriversListScreen({super.key});

  @override
  ConsumerState<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends ConsumerState<DriversListScreen> {
  bool _loading = false;
  String? _error;
  List<Driver> _rows = const [];
  final _searchCtrl = TextEditingController();

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
      final terminal = ref.read(selectedTerminalIdProvider);
      final svc = ref.read(driversServiceProvider);
      _rows = await svc.list(terminalCode: terminal, q: _searchCtrl.text);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search name, email, phone',
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _refresh();
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _refresh(),
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
          Expanded(
            child: _rows.isEmpty
                ? const Center(child: Text('No drivers found'))
                : ListView.separated(
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = _rows[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(d.status).withAlpha(38),
                          child: Icon(
                            Icons.person,
                            color: _statusColor(d.status),
                          ),
                        ),
                        title: Text(d.name),
                        subtitle: Text(
                          '${d.email ?? ''}${d.email != null && d.phone != null ? ' • ' : ''}${d.phone ?? ''}\nStatus: ${d.status} • HOS left: ${d.hosHoursLeft.toStringAsFixed(1)}h',
                        ),
                        isThreeLine: true,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/drivers/${d.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
