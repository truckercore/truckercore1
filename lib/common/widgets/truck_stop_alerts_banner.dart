import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/truck_stop_services.dart';

class TruckStopAlertsBanner extends ConsumerStatefulWidget {
  final String truckStopId;
  const TruckStopAlertsBanner({super.key, required this.truckStopId});

  @override
  ConsumerState<TruckStopAlertsBanner> createState() =>
      _TruckStopAlertsBannerState();
}

class _TruckStopAlertsBannerState extends ConsumerState<TruckStopAlertsBanner> {
  final List<TruckStopAlert> _alerts = [];
  StreamSubscription<TruckStopAlert>? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() async {
    final svc = ref.read(truckStopServiceProvider);
    final recent = await svc.fetchRecentAlerts(widget.truckStopId, limit: 5);
    if (mounted) {
      setState(() {
        _alerts
          ..clear()
          ..addAll(recent);
        _loading = false;
      });
    }
    _sub = svc.alertsRealtimeStream(widget.truckStopId).listen((a) {
      setState(() {
        _alerts.insert(0, a);
        if (_alerts.length > 5) _alerts.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (_alerts.isEmpty) return const SizedBox.shrink();

    Color badgeColor(String s) {
      switch (s) {
        case 'warning':
          return Colors.amber;
        case 'critical':
          return Colors.red;
        default:
          return Colors.blue;
      }
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Alerts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final a in _alerts.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor(a.severity),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        a.severity.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
