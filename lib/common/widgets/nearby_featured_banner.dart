import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../common/services/truck_stop_services.dart';
import '../../common/utils/geo.dart';
import 'featured_badge.dart';

class NearbyFeaturedBanner extends ConsumerWidget {
  final double radiusMiles;
  const NearbyFeaturedBanner({super.key, this.radiusMiles = 25});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<_FeaturedStop>>(
      future: _load(ref),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: ListTile(
                title: const Text('Nearby Featured Stops'),
                subtitle: Text('Error: ${snap.error}'),
                trailing: TextButton(
                  onPressed: () => context.push('/truck-stops'),
                  child: const Text('Open'),
                ),
              ),
            ),
          );
        }
        final items = snap.data ?? const <_FeaturedStop>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: ListTile(
                title: const Text('Nearby Featured Stops'),
                subtitle: const Text(
                  'No featured stops within your radius. Try Truck Stops.',
                ),
                trailing: TextButton(
                  onPressed: () => context.push('/truck-stops'),
                  child: const Text('View all'),
                ),
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nearby Featured Stops',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final s in items.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const FeaturedBadge(featured: true),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${s.distanceMiles.toStringAsFixed(1)} mi'),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/truck-stops'),
                    child: const Text('View all'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<_FeaturedStop>> _load(WidgetRef ref) async {
    final svc = ref.read(truckStopServiceProvider);
    final you = await safeCurrentPosition();
    if (you == null) return const [];
    final stops = await svc.fetchTruckStops();
    final here = LatLng(you.latitude, you.longitude);
    final featured = stops
        .where((s) => s.tier != 'free')
        .map((s) {
          final dist = milesBetween(here, LatLng(s.lat, s.lng));
          return _FeaturedStop(s.id, s.name, dist);
        })
        .where((s) => s.distanceMiles <= radiusMiles)
        .toList();
    featured.sort((a, b) => a.distanceMiles.compareTo(b.distanceMiles));
    return featured;
  }
}

class _FeaturedStop {
  final String id;
  final String name;
  final double distanceMiles;
  _FeaturedStop(this.id, this.name, this.distanceMiles);
}
