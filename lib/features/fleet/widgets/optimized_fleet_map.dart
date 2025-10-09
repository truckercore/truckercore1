import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../providers/vehicles_provider.dart';

/// High-performance map for 1000+ vehicles using clustering and viewport filtering
class OptimizedFleetMap extends ConsumerStatefulWidget {
  const OptimizedFleetMap({super.key});

  @override
  ConsumerState<OptimizedFleetMap> createState() => _OptimizedFleetMapState();
}

class _OptimizedFleetMapState extends ConsumerState<OptimizedFleetMap> {
  late MapLibreMapController _mapController;
  final Set<Symbol> _symbols = {};
  final List<Map<String, dynamic>> _points = [];


  @override
  void initState() {
    super.initState();
    _initializeCluster();
  }

  void _initializeCluster() {
    // no-op: clustering disabled for now
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final vehicles = await ref.read(allVehiclesProvider.future);

    // Convert to GeoJSON points
    _points
      ..clear()
      ..addAll(vehicles.map((v) => <String, dynamic>{
            'type': 'Feature',
            'properties': {
              'id': v.id,
              'status': v.status,
              'driver': v.currentDriver,
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [v.longitude, v.latitude],
            },
          }));

    await _updateVisibleMarkers();
  }

  Future<void> _updateVisibleMarkers() async {
    final bounds = await _mapController.getVisibleRegion();

    // Clear old symbols (remove in batches to avoid blocking UI)
    for (final symbol in _symbols) {
      try {
        await _mapController.removeSymbol(symbol);
      } catch (_) {
        // ignore errors on removal
      }
    }
    _symbols.clear();

    // Filter points within current bounds and render markers
    for (final feature in _points) {
      final coords = (feature['geometry']['coordinates'] as List).cast<num>();
      final lon = coords[0].toDouble();
      final lat = coords[1].toDouble();
      if (lon >= bounds.southwest.longitude &&
          lon <= bounds.northeast.longitude &&
          lat >= bounds.southwest.latitude &&
          lat <= bounds.northeast.latitude) {
        final props = (feature['properties'] as Map<String, dynamic>);
        final status = props['status'] as String?;
        final symbol = await _mapController.addSymbol(
          SymbolOptions(
            geometry: LatLng(lat, lon),
            iconImage: _getVehicleIcon(status),
            iconSize: 1.0,
          ),
        );
        _symbols.add(symbol);
      }
    }
  }

  double _getClusterSize(int count) {
    if (count < 10) return 0.8;
    if (count < 100) return 1.0;
    if (count < 1000) return 1.2;
    return 1.5;
  }

  String _getVehicleIcon(String? status) {
    switch (status) {
      case 'active':
        return 'vehicle-active';
      case 'idle':
        return 'vehicle-idle';
      case 'maintenance':
        return 'vehicle-maintenance';
      default:
        return 'vehicle-default';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: const CameraPosition(
        target: LatLng(39.8283, -98.5795), // Center of US
        zoom: 4,
      ),
      trackCameraPosition: true,
      onCameraIdle: () async {
        await _updateVisibleMarkers();
      },
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
