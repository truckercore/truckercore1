import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _sb = Supabase.instance.client;

Future<Map<String, dynamic>?> fetchParkingStatus({String? stopId, double? lat, double? lng}) async {
  final body = <String, dynamic>{};
  if (stopId != null) body['stop_id'] = stopId;
  if (lat != null && lng != null) {
    body['lat'] = lat;
    body['lng'] = lng;
  }
  final res = await _sb.functions.invoke('parking-status', body: body);
  return res.data == null ? null : Map<String, dynamic>.from(res.data as Map);
}

Future<void> submitParkingReport({
  required String stopId,
  required String kind, // 'open'|'limited'|'full'|'count'
  int? value,
}) async {
  await _sb.functions.invoke('parking-report', body: {
    'stop_id': stopId,
    'kind': kind,
    if (value != null) 'value': value,
  });
}

class ParkingAvailabilityCard extends StatefulWidget {
  final String stopId;
  const ParkingAvailabilityCard({super.key, required this.stopId});

  @override
  State<ParkingAvailabilityCard> createState() => _ParkingAvailabilityCardState();
}

class _ParkingAvailabilityCardState extends State<ParkingAvailabilityCard> {
  Map<String, dynamic>? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await fetchParkingStatus(stopId: widget.stopId);
      if (!mounted) return;
      setState(() {
        _status = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _tone(double conf) {
    if (conf >= 0.8) return Colors.green.shade100;
    if (conf >= 0.5) return Colors.amber.shade100;
    return Colors.red.shade100;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: ListTile(
          title: Text('Parking'),
          trailing: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_status == null) {
      return Card(
        child: ListTile(
          title: const Text('Parking'),
          subtitle: const Text('No data'),
          trailing: TextButton(onPressed: _load, child: const Text('Refresh')),
        ),
      );
    }

    final est = _status!['available_estimate'] as int?; // e.g., 18
    final conf = (_status!['confidence'] as num?)?.toDouble() ?? 0;
    final by = _status!['last_reported_by'] as String? ?? 'unknown';
    final last = _status!['last_reported_at'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_parking),
                const SizedBox(width: 8),
                const Text('Parking Availability', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: _load, child: const Text('Refresh')),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _tone(conf), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                Text(
                  est != null ? '$est spots' : 'Unknown',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Chip(label: Text('Confidence ${(conf * 100).toStringAsFixed(0)}%')),
                const Spacer(),
                Text('by $by • ${last.isNotEmpty ? last : '—'}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => submitParkingReport(stopId: widget.stopId, kind: 'open'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Open'),
                ),
                OutlinedButton.icon(
                  onPressed: () => submitParkingReport(stopId: widget.stopId, kind: 'limited'),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Limited'),
                ),
                OutlinedButton.icon(
                  onPressed: () => submitParkingReport(stopId: widget.stopId, kind: 'full'),
                  icon: const Icon(Icons.block),
                  label: const Text('Full'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
