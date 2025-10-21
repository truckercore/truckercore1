import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'truck_restrictions.dart';
import 'truck_restrictions_providers.dart';
import 'truck_restrictions_repository.dart';

/// A light-weight overlay for FlutterMap that fetches truck restrictions by state
/// and renders markers/polylines.
class TruckRestrictionsLayer extends ConsumerStatefulWidget {
  final String stateCode; // e.g., 'NH'
  final MapController? controller; // optional: for future bbox-based queries
  final int limit;
  const TruckRestrictionsLayer({
    super.key,
    required this.stateCode,
    this.controller,
    this.limit = 800,
  });

  @override
  ConsumerState<TruckRestrictionsLayer> createState() => _TruckRestrictionsLayerState();
}

class _TruckRestrictionsLayerState extends ConsumerState<TruckRestrictionsLayer> {
  late final TruckRestrictionsRepository _repo = ref.read(truckRestrictionsRepositoryProvider);
  late Future<List<TruckRestriction>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(widget.stateCode);
  }

  Future<List<TruckRestriction>> _load(String state) async {
    try {
      // Prefer RPC get_state_overlays for server-side shape/filtering
      return await _repo.fetchOverlaysByStateRpc(state, limit: widget.limit);
    } catch (_) {
      // Fallback to direct table query if RPC not available
      return _repo.fetchByState(state, limit: widget.limit);
    }
  }

  @override
  void didUpdateWidget(covariant TruckRestrictionsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateCode != widget.stateCode) {
      setState(() {
        _future = _load(widget.stateCode);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TruckRestriction>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final items = snapshot.data ?? const <TruckRestriction>[];
        final markers = <Marker>[];
        final polylines = <Polyline>[];

        for (final r in items) {
          final loc = r.location;
          final lat = (loc?['lat'] ?? loc?['latitude']) as num?;
          final lng = (loc?['lng'] ?? loc?['lon'] ?? loc?['longitude']) as num?;
          if (lat != null && lng != null) {
            final point = LatLng(lat.toDouble(), lng.toDouble());
            if (r.category == 'low_clearance') {
              markers.add(_lowClearanceMarker(point, r.description));
            } else if (r.category == 'weigh_station') {
              markers.add(_weighStationMarker(point, r.description));
            } else if (r.category == 'restricted_route') {
              // If geometry available in future, draw as dashed polyline. For now, place a red marker.
              markers.add(_restrictedRouteMarker(point, r.description));
            }
          }
        }

        return Stack(
          children: [
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        );
      },
    );
  }

  Marker _lowClearanceMarker(LatLng p, String label) => Marker(
        point: p,
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LC',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.location_on, color: Colors.red, size: 28),
            _label(label),
          ],
        ),
      );

  Marker _weighStationMarker(LatLng p, String label) => Marker(
        point: p,
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'WS',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.location_on, color: Colors.blue, size: 28),
            _label(label),
          ],
        ),
      );

  Marker _restrictedRouteMarker(LatLng p, String label) => Marker(
        point: p,
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'RR',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
            _label(label),
          ],
        ),
      );

  Widget _label(String label) => Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      );
}
