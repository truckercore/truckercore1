// lib/features/admin/operators/admin_operators_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/services/truck_stop_services.dart';

final adminCurrentStopIdProvider = StateProvider<String?>((_) => null);

class AdminOperatorsScreen extends ConsumerStatefulWidget {
  const AdminOperatorsScreen({super.key});

  @override
  ConsumerState<AdminOperatorsScreen> createState() =>
      _AdminOperatorsScreenState();
}

class _AdminOperatorsScreenState extends ConsumerState<AdminOperatorsScreen> {
  bool _loading = false;
  List<TruckStop> _stops = const [];
  List<String> _userIds = const [];
  String? _error;

  final _userIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStopsAndLinks();
  }

  Future<void> _loadStopsAndLinks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(truckStopServiceProvider);
      // Admin sees all stops; if your RLS restricts, use an admin service/account or a secure function.
      _stops = await svc.fetchTruckStops();
      final current = ref.read(adminCurrentStopIdProvider);
      if (current == null && _stops.isNotEmpty) {
        ref.read(adminCurrentStopIdProvider.notifier).state = _stops.first.id;
      }
      await _loadLinks();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLinks() async {
    final svc = ref.read(truckStopServiceProvider);
    final stopId = ref.read(adminCurrentStopIdProvider);
    if (stopId == null) {
      setState(() => _userIds = const []);
      return;
    }
    final list = await svc.listOperatorUserIds(stopId);
    setState(() => _userIds = list);
  }

  Future<void> _addOperator() async {
    final stopId = ref.read(adminCurrentStopIdProvider);
    if (stopId == null) return;
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a user_id (UUID) to link.')),
      );
      return;
    }
    final svc = ref.read(truckStopServiceProvider);
    try {
      await svc.linkOperator(userId: userId, truckStopId: stopId);
      _userIdCtrl.clear();
      await _loadLinks();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Operator linked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to link: $e')));
      }
    }
  }

  Future<void> _removeOperator(String userId) async {
    final stopId = ref.read(adminCurrentStopIdProvider);
    if (stopId == null) return;
    final svc = ref.read(truckStopServiceProvider);
    try {
      await svc.unlinkOperator(userId: userId, truckStopId: stopId);
      await _loadLinks();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Operator unlinked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unlink: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopId = ref.watch(adminCurrentStopIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Operator Access'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadLinks,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Row(
              children: [
                const Text('Truck Stop:'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String?>(
                    value: _stops.any((s) => s.id == stopId) ? stopId : null,
                    isExpanded: true,
                    hint: const Text('Select a truck stop'),
                    items: _stops
                        .map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      ref.read(adminCurrentStopIdProvider.notifier).state = v;
                      await _loadLinks();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'User ID (UUID)',
                          hintText: 'paste auth user_id',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Link'),
                      onPressed: _addOperator,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _userIds.isEmpty
                  ? const Center(child: Text('No operators linked yet'))
                  : ListView.separated(
                      itemCount: _userIds.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final uid = _userIds[i];
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(uid),
                          trailing: IconButton(
                            tooltip: 'Unlink',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _removeOperator(uid),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
