import 'package:flutter/material.dart';
import '../../../services/roaddogg_service.dart';

class RoaddoggMatchScreen extends StatefulWidget {
  final RoaddoggService rd;
  final String loadId;
  const RoaddoggMatchScreen({
    super.key,
    required this.rd,
    required this.loadId,
  });

  @override
  State<RoaddoggMatchScreen> createState() => _RoaddoggMatchScreenState();
}

class _RoaddoggMatchScreenState extends State<RoaddoggMatchScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.rd.scoreLoad(widget.loadId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roaddogg — Best Matches')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data as Map<String, dynamic>;
          final matches = (d['matches'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
          final conf = (d['confidence'] ?? 'high') as String;
          if (matches.isEmpty) {
            return const Center(child: Text('No eligible drivers found'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = matches[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text('Driver ${m['driver_id']}'),
                subtitle: Text(m['rationale'] ?? ''),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (m['score'] as num).toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (i == 0)
                      Text(
                        'Confidence: $conf',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                onTap: () {
                  // TODO: Navigate to assign driver flow
                },
              );
            },
          );
        },
      ),
    );
  }
}
