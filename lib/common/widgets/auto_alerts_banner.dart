// lib/common/widgets/auto_alerts_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../services/truck_stop_services.dart';
import '../utils/geo.dart';
import 'truck_stop_alerts_banner.dart';

class AutoAlertsBanner extends ConsumerStatefulWidget {
  final double radiusMiles; // search radius
  const AutoAlertsBanner({super.key, this.radiusMiles = 25});

  @override
  ConsumerState<AutoAlertsBanner> createState() => _AutoAlertsBannerState();
}

class _AutoAlertsBannerState extends ConsumerState<AutoAlertsBanner> {
  String? _stopId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _findNearest();
  }

  Future<void> _findNearest() async {
    final you = await safeCurrentPosition();
    if (you == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final svc = ref.read(truckStopServiceProvider);
    final stops = await svc.fetchTruckStops();

    // Featured = tier != free
    final featured = stops.where((s) => s.tier != 'free').toList();
    if (featured.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final here = LatLng(you.latitude, you.longitude);
    String? bestId;
    double bestDist = double.infinity;
    for (final s in featured) {
      final d = const Distance()(here, LatLng(s.lat, s.lng)) / 1609.344;
      if (d <= widget.radiusMiles && d < bestDist) {
        bestDist = d;
        bestId = s.id;
      }
    }
    if (mounted) {
      setState(() {
        _stopId = bestId;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (_stopId == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Live Alerts'),
            subtitle: const Text(
              'No nearby featured stop found. Open Truck Stops to choose one.',
            ),
            trailing: TextButton(
              onPressed: () => context.push('/truck-stops'),
              child: const Text('Open'),
            ),
          ),
        ),
      );
    }
    return TruckStopAlertsBanner(truckStopId: _stopId!);
  }
}
