import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service/safety_service.dart';

class SafetyPanel extends ConsumerStatefulWidget {
  const SafetyPanel({super.key});

  @override
  ConsumerState<SafetyPanel> createState() => _SafetyPanelState();
}

class _SafetyPanelState extends ConsumerState<SafetyPanel> {
  bool _loading = false;
  List<SafetyRecord> _items = const [];
  String? _error;

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
      final svc = ref.read(safetyServiceProvider);
      _items = await svc.listDriverSafety();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Error: $_error'),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No drivers or no telemetry available.'),
      );
    }

    return Column(
      children: _items.map((r) {
        final color = _gradeColor(r.grade);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                r.grade,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text('Driver ${_short(r.driverUserId)} • Score ${r.score}'),
            subtitle: Text(
              'Trips: ${r.trips} • Harsh brakes: ${r.harshBrakes} • Overspeed: ${r.overspeedMinutes} min • Long drive: ${r.longDriveHours} h\n${r.flags.join(' • ')}',
            ),
            isThreeLine: true,
            trailing: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Driver profile coming soon')),
                );
              },
              child: const Text('Profile'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _gradeColor(String g) {
    switch (g) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.lightGreen;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }

  String _short(String id) => id.length > 8 ? '${id.substring(0, 8)}…' : id;
}
