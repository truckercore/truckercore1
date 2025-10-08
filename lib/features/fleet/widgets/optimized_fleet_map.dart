import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supercluster/supercluster.dart';

import '../providers/vehicles_provider.dart';

/// High-performance map for 1000+ vehicles using clustering and viewport filtering
class OptimizedFleetMap extends ConsumerStatefulWidget {
  const OptimizedFleetMap({super.key});

  @override
  ConsumerState<OptimizedFleetMap> createState() => _OptimizedFleetMapState();
}

class _OptimizedFleetMapState extends ConsumerState<OptimizedFleetMap> {
  MapLibreMapController? _mapController;
  Supercluster? _cluster;
  final Set<Symbol> _symbols = {};

  static const _clusterRadius = 60;
  static const _minZoom = 0;
  static const _maxZoom = 16;

  @override
  void initState() {
    super.initState();
    _initializeCluster();
  }

  void _initializeCluster() {
    _cluster = Supercluster(
      radius: _clusterRadius,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      extent: 512,
      nodeSize: 64,
    );
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
    controller.onCameraIdle = _updateVisibleMarkers;

    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final vehicles = await ref.read(allVehiclesProvider.future);

    // Convert to GeoJSON points
    final points = vehicles.map((v) => <String, dynamic>{
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
        }).toList();

    _cluster!.load(points);
    await _updateVisibleMarkers();
  }

  Future<void> _updateVisibleMarkers() async {
    if (_mapController == null || _cluster == null) return;

    final bounds = await _mapController!.getVisibleRegion();
    final zoom = (await _mapController!.getCameraPosition()).zoom.toInt();

    final bbox = [
      bounds.southwest.longitude,
      bounds.southwest.latitude,
      bounds.northeast.longitude,
      bounds.northeast.latitude,
    ];

    final clusters = _cluster!.getClusters(bbox, zoom);

    // Clear old symbols (remove in batches to avoid blocking UI)
    for (final symbol in _symbols) {
      try {
        await _mapController!.removeSymbol(symbol);
      } catch (_) {
        // ignore errors on removal
      }
    }
    _symbols.clear();

    for (final cluster in clusters) {
      final props = cluster['properties'] as Map<String, dynamic>;
      final coords = (cluster['geometry']['coordinates'] as List).cast<num>();
      final isCluster = props.containsKey('cluster');

      if (isCluster) {
        final count = (props['point_count'] as num).toInt();
        final symbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(coords[1].toDouble(), coords[0].toDouble()),
            iconImage: 'cluster-icon', // Ensure sprite exists in style
            iconSize: _getClusterSize(count),
            textField: count.toString(),
            textSize: 12,
            textColor: '#ffffff',
          ),
        );
        _symbols.add(symbol);
      } else {
        final status = props['status'] as String?;
        final symbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(coords[1].toDouble(), coords[0].toDouble()),
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
      styleString: 'https://demotiles.maplibre.org/style.json',
      myLocationEnabled: false,
      trackCameraPosition: true,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
