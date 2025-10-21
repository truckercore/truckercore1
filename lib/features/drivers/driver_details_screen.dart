import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/telematics_service.dart';

class DriverDetailsScreen extends ConsumerWidget {
  final String driverUserId;
  const DriverDetailsScreen({super.key, required this.driverUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Driver Details'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Telemetry'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProfileTab(driverUserId: driverUserId),
            _TelemetryTab(driverUserId: driverUserId),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String driverUserId;
  const _ProfileTab({required this.driverUserId});
  @override
  Widget build(BuildContext context) {
    // MVP profile placeholder
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ListTile(
          leading: const Icon(Icons.person),
          title: Text('Driver ID: $driverUserId'),
        ),
        const ListTile(
          leading: Icon(Icons.badge),
          title: Text('Status: Active'),
        ),
      ],
    );
  }
}

class _TelemetryTab extends ConsumerStatefulWidget {
  final String driverUserId;
  const _TelemetryTab({required this.driverUserId});
  @override
  ConsumerState<_TelemetryTab> createState() => _TelemetryTabState();
}

class _TelemetryTabState extends ConsumerState<_TelemetryTab> {
  late Future<List<TelematicsEvent>> _future;
  @override
  void initState() {
    super.initState();
    _future = ref
        .read(telematicsServiceProvider)
        .telemetryHistory(widget.driverUserId, limit: 200);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TelematicsEvent>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return const Center(child: Text('No telemetry yet.'));
        }
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = rows[i];
            IconData icon;
            Color color;
            switch (e.type) {
              case 'speeding':
                icon = Icons.speed;
                color = Colors.redAccent;
                break;
              case 'idle':
                icon = Icons.timelapse;
                color = Colors.amber;
                break;
              case 'harsh_brake':
                icon = Icons.report;
                color = Colors.orange;
                break;
              case 'harsh_turn':
                icon = Icons.rotate_right;
                color = Colors.orange;
                break;
              case 'accel':
                icon = Icons.flash_on;
                color = Colors.orange;
                break;
              default:
                icon = Icons.circle;
                color = Colors.grey;
                break;
            }
            return ListTile(
              leading: Icon(icon, color: color),
              title: Text(e.type.replaceAll('_', ' ')),
              subtitle: Text(e.occurredAt.toLocal().toString()),
              trailing: e.data.isEmpty ? null : const Icon(Icons.chevron_right),
            );
          },
        );
      },
    );
  }
}
