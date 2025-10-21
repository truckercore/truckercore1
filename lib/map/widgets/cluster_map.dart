// lib/map/widgets/cluster_map.dart
// A reusable widget that renders a flutter_map with clustered StopPins.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../data/poi_promos_repository.dart';
import '../scoring.dart';
import '../stop_pin.dart';

class ClusterMap extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final PoiPromosRepository? repository;
  final Future<String?> Function()? getAuthToken;

  const ClusterMap({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialZoom = 9,
    this.repository,
    this.getAuthToken,
  });

  @override
  State<ClusterMap> createState() => _ClusterMapState();
}

class _ClusterMapState extends State<ClusterMap> {
  late final MapController _mapController;
  late PoiPromosRepository _repo;
  List<StopPin> _pins = const [];
  StopPin? _globalBest;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _repo = widget.repository ?? PoiPromosRepository(getAuthToken: widget.getAuthToken);
    // initial load
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPins());
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refreshPins() async {
    // debounce to avoid rapid spam during pans/zooms
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () async {
      final bounds = _currentBounds();
      if (bounds == null) return;
      final bbox = (west: bounds.west, south: bounds.south, east: bounds.east, north: bounds.north);
      final pins = await _repo.fetchPins(
        userLat: _mapController.camera.center.latitude,
        userLng: _mapController.camera.center.longitude,
        bbox: bbox,
      );
      pins.sort((a, b) => computeScore(b).compareTo(computeScore(a)));
      setState(() {
        _pins = pins;
        _globalBest = pins.isNotEmpty ? pins.first : null;
      });
    });
  }

  _Bbox? _currentBounds() {
    final b = _mapController.camera.visibleBounds;
    return _Bbox(
      west: b.west,
      east: b.east,
      south: b.south,
      north: b.north,
    );
  }

  Color _occColor(String occ) {
    switch (occ) {
      case 'open':
        return Colors.green.shade600;
      case 'some':
        return Colors.orange.shade700;
      case 'full':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _pinWidget(StopPin p) {
    final color = _occColor(p.occupancy);
    final borderColor = color.withValues(alpha: (0.3 + 0.7 * p.confidence).clamp(0.0, 1.0).toDouble());
    return Tooltip(
      message: '${p.name}\n${p.distanceMi.toStringAsFixed(1)} mi',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
        ),
        alignment: Alignment.center,
        child: Text(
          p.fuelDiscountCents != null && p.fuelDiscountCents! > 0 ? '${p.fuelDiscountCents}¢' : '',
          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _onClusterTap(List<Marker> markers) {
    final pins = markers.map((m) => m.key is ValueKey<StopPin> ? (m.key as ValueKey<StopPin>).value : null).whereType<StopPin>().toList();
    if (pins.isEmpty) return;
    final rep = pickRep(pins);
    pins.sort((a, b) => computeScore(b).compareTo(computeScore(a)));

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cluster details', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _bestTile(rep, isGlobal: false),
                const Divider(),
                ...pins.map((p) => _pinTile(p)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bestBanner() {
    final b = _globalBest;
    if (b == null) return const SizedBox.shrink();
    // derive primary badge from top factor
    final f = b.factors();
    final top = (f.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    String badge = 'Best Value';
    if (top == 'fuel') {
      badge = 'Cheapest fuel';
    } else if (top == 'parking') {
      badge = 'Most parking now';
    } else if (top == 'distance') {
      badge = 'Closest';
    }

    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.indigo.shade50,
      child: ListTile(
        leading: const Icon(Icons.emoji_events, color: Colors.indigo),
        title: Text('Best for you: ${b.name}'),
        subtitle: Text(badge),
        onTap: () {
          _mapController.move(LatLng(b.lat, b.lng), _mapController.camera.zoom);
        },
      ),
    );
  }

  Widget _pinTile(StopPin p) {
    final f = p.factors();
    return ListTile(
      dense: true,
      leading: Icon(Icons.local_parking, color: _occColor(p.occupancy)),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Score: ${computeScore(p).toStringAsFixed(2)} • ${p.distanceMi.toStringAsFixed(1)} mi'),
      trailing: Wrap(
        spacing: 8,
        children: [
          _chip('P ${(f['parking'] ?? 0).toStringAsFixed(2)}'),
          _chip('F ${(f['fuel'] ?? 0).toStringAsFixed(2)}'),
          _chip('L ${(f['loyalty'] ?? 0).toStringAsFixed(2)}'),
          _chip('A ${(f['amenities'] ?? 0).toStringAsFixed(2)}'),
          _chip('D ${(f['distance'] ?? 0).toStringAsFixed(2)}'),
          _chip('C ${(f['confidence'] ?? 0).toStringAsFixed(2)}'),
        ],
      ),
      onTap: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _bestTile(StopPin p, {required bool isGlobal}) {
    final f = p.factors();
    return ListTile(
      leading: const Icon(Icons.recommend, color: Colors.green),
      title: Text(isGlobal ? 'Best for you: ${p.name}' : 'Best in this cluster: ${p.name}'),
      subtitle: Text('Score ${computeScore(p).toStringAsFixed(2)} • ${p.distanceMi.toStringAsFixed(1)} mi'),
      trailing: Wrap(
        spacing: 8,
        children: [
          _chip('Parking ${(f['parking'] ?? 0).toStringAsFixed(2)}'),
          _chip('Fuel ${(f['fuel'] ?? 0).toStringAsFixed(2)}'),
          _chip('Conf ${(f['confidence'] ?? 0).toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _chip(String s) => Chip(label: Text(s));

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.initialLat, widget.initialLng);

    return Column(
      children: [
        _bestBanner(),
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: widget.initialZoom,
              onMapEvent: (evt) {
                if (evt is MapEventMoveEnd || evt is MapEventRotateEnd || evt is MapEventFlingAnimationEnd) {
                  _refreshPins();
                } else if (evt is MapEventMove) {
                  // light debounce during pan
                  _repo.debounce();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.truckercore.app',
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(40, 40),
                  builder: (context, markers) {
                    final count = markers.length;
                    return GestureDetector(
                      onTap: () => _onClusterTap(markers),
                      child: CircleAvatar(
                        backgroundColor: Colors.blue.shade600,
                        child: Text('$count', style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                  markers: _pins
                      .map((p) => Marker(
                            key: ValueKey<StopPin>(p),
                            point: LatLng(p.lat, p.lng),
                            width: 40,
                            height: 40,
                            child: _pinWidget(p),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bbox {
  final double west, south, east, north;
  _Bbox({required this.west, required this.south, required this.east, required this.north});
}
