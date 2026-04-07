// lib/widgets/parking_card.dart
// Parking card with premium vs free rendering, confidence tone, relative age, cooldown on reports, and haptics.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/parking_status.dart';
import '../services/parking_service.dart';

class ParkingCard extends StatefulWidget {
  final ParkingService service;
  final String stopId;
  final String? deviceHash;
  const ParkingCard({super.key, required this.service, required this.stopId, this.deviceHash});

  @override
  State<ParkingCard> createState() => _ParkingCardState();
}

class _ParkingCardState extends State<ParkingCard> {
  ParkingStatus? status;
  bool loading = true;
  String? error;
  DateTime? _lastReportAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final s = await widget.service.getStatus(widget.stopId);
      if (!mounted) return;
      setState(() { status = s; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _report(String kind, {int? value}) async {
    try {
      await widget.service.report(stopId: widget.stopId, kind: kind, value: value, deviceHash: widget.deviceHash);
      _lastReportAt = DateTime.now();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for reporting!')));
      }
      try { HapticFeedback.mediumImpact(); } catch (_) {}
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report failed: $e')));
    }
  }

  bool get _rateLimited {
    if (_lastReportAt == null) return false;
    return DateTime.now().difference(_lastReportAt!) < const Duration(minutes: 10);
  }

  Color _tone(double conf) => conf >= 0.8
      ? Colors.green.shade100
      : conf >= 0.5
          ? Colors.amber.shade100
          : Colors.red.shade100;

  String _ago(DateTime? t) {
    if (t == null) return '—';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }

  Future<int?> _promptCount(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report count'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Spots available'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return null;
    return int.tryParse(ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        child: ListTile(
          title: Text('Parking'),
          trailing: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (error != null) {
      return Card(
        child: ListTile(
          title: const Text('Parking'),
          subtitle: Text('Error: $error'),
          trailing: TextButton(onPressed: _load, child: const Text('Retry')),
        ),
      );
    }
    if (status == null) {
      return Card(
        child: ListTile(
          title: const Text('Parking'),
          subtitle: const Text('No data'),
          trailing: TextButton(onPressed: _load, child: const Text('Refresh')),
        ),
      );
    }

    final s = status!;
    final conf = (s.confidence ?? 0).clamp(0, 1).toDouble();

    final header = Row(children: [
      const Icon(Icons.local_parking),
      const SizedBox(width: 8),
      const Text('Parking Availability', style: TextStyle(fontWeight: FontWeight.bold)),
      const Spacer(),
      TextButton(onPressed: _load, child: const Text('Refresh')),
    ]);

    final bodyPremium = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _tone(conf), borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Text('Open: ${s.availableEstimate ?? "—"} / ${s.availableTotal ?? "—"}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Chip(label: Text('Conf ${(conf * 100).toStringAsFixed(0)}%')),
        const Spacer(),
        Text('${s.lastReportedBy ?? "—"} • ${_ago(s.lastReportedAt)}', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );

    final bodyFree = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _tone(conf), borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Text('Status: ${s.statusBucket ?? "—"}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Chip(label: Text('Conf ${(conf * 100).toStringAsFixed(0)}%')),
        const Spacer(),
        Text('${s.lastReportedBy ?? "—"} • ${_ago(s.lastReportedAt)}', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );

    // Optional breakdown chips
    final breakdown = s.breakdown;
    final breakdownRow = breakdown == null || breakdown.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 6, children: [
              if (breakdown['operator_reports'] != null)
                Chip(label: Text('Operator ${breakdown['operator_reports']}')),
              if (breakdown['driver_reports'] != null)
                Chip(label: Text('Driver ${breakdown['driver_reports']}')),
              if (breakdown['sensor_reports'] != null)
                Chip(label: Text('Sensor ${breakdown['sensor_reports']}')),
            ]),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          header,
          const SizedBox(height: 8),
          s.isPremium ? bodyPremium : bodyFree,
          breakdownRow,
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: _rateLimited ? null : () => _report('open'), child: const Text('Open')),
              OutlinedButton(onPressed: _rateLimited ? null : () => _report('limited'), child: const Text('Limited')),
              OutlinedButton(onPressed: _rateLimited ? null : () => _report('full'), child: const Text('Full')),
              OutlinedButton(
                onPressed: _rateLimited
                    ? null
                    : () async {
                        final val = await _promptCount(context);
                        if (val != null) _report('count', value: val);
                      },
                child: const Text('Count…'),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
