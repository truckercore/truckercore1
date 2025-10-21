import 'package:flutter/material.dart';
import '../../../services/hos_read_service.dart';

class HosViewerPanel extends StatefulWidget {
  final HosReadService svc;
  final String driverId;
  const HosViewerPanel({super.key, required this.svc, required this.driverId});
  @override
  State<HosViewerPanel> createState() => _HosViewerPanelState();
}

class _HosViewerPanelState extends State<HosViewerPanel> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.svc.listSegments(widget.driverId);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            );
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const ListTile(title: Text('No HOS segments'));
          }
          return Column(
            children: rows.take(20).map((r) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.schedule),
                title: Text(
                  '${r['status']}  •  ${r['start_time']} → ${r['end_time'] ?? 'now'}',
                ),
                subtitle: Text(
                  'source: ${r['source']} • provider: ${r['eld_provider'] ?? '-'}',
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
