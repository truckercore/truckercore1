import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:truckercore1/features/gps/gps_service.dart';

import '../../common/models/app_role.dart';
import '../../common/state/session_provider.dart';
import '../../core/env/assert_env.dart';
import '../../core/supabase/supabase_provider.dart';
import '../route_planning/truck_restrictions_layer.dart';
import 'state/gps_map_providers.dart';

class GpsMapScreen extends ConsumerStatefulWidget {
  const GpsMapScreen({super.key});

  @override
  ConsumerState<GpsMapScreen> createState() => _GpsMapScreenState();
}

class _GpsMapScreenState extends ConsumerState<GpsMapScreen> {
  bool _showRestrictions = false;
  String _stateCode = 'NH';
  bool _heatmap = false;
  final MapController _mapController = MapController();
  LatLng? _lastTruckPos;
  final List<LatLng> _trail = <LatLng>[];
  bool _paused = false;
  bool _listenerSet = false; // guard so we attach the listener only once

  @override
  Widget build(BuildContext context) {
    // Developer-friendly env check (debug only)
    final env = ref.read(appEnvProvider);
    assertEnv(context, env);

    final token = ref.watch(mapboxTokenProvider);
    final center = ref.watch(mapCenterProvider);
    final zoom = ref.watch(mapZoomProvider);

    // Attach the stream listener safely (once) during build.
    if (!_listenerSet) {
      _listenerSet = true;
      ref.listen<AsyncValue<LatLng>>(truckPositionStreamProvider, (prev, next) {
        next.whenData((p) {
          if (_paused) return;
          setState(() {
            _lastTruckPos = p;
            _trail.add(p);
            if (_trail.length > 200) {
              _trail.removeAt(0);
            }
          });
        });
      });
    }

    if (token.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Real-Time GPS')),
        body: const Center(
          child: Text(
            'MAPBOX_TOKEN not set.\nRun with --dart-define=MAPBOX_TOKEN=pk.your_token',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final urlTemplate =
        'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$token';

    final ownerOp = ref.watch(sessionProvider).role == AppRole.ownerOperator;

    final markerPos = _lastTruckPos ?? center;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time GPS'),
        actions: [
          if (ownerOp)
            FilterChip(
              label: const Text('Heatmap'),
              selected: _heatmap,
              onSelected: (v) => setState(() => _heatmap = v),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: zoom),
            children: [
              if (_showRestrictions)
                TruckRestrictionsLayer(stateCode: _stateCode, controller: _mapController),
              TileLayer(
                urlTemplate: urlTemplate,
                userAgentPackageName: 'com.example.truckercore',
                tileProvider: NetworkTileProvider(),
              ),
              PolylineLayer(
                polylines: [
                  if (_trail.length >= 2)
                    Polyline(
                      points: _trail,
                      color: Colors.blueAccent,
                      strokeWidth: 4,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: markerPos,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.local_shipping,
                      color: Colors.blue,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_heatmap && ownerOp)
            IgnorePointer(
              child: Container(
                color: Colors.red.withValues(alpha: 0.08),
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.all(8),
                child: const Chip(label: Text('Heatmap overlay (MVP)')),
              ),
            ),
          Positioned(
            right: 8,
            top: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Restrictions'),
                        Switch(
                          value: _showRestrictions,
                          onChanged: (v) => setState(() => _showRestrictions = v),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'State code',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(text: _stateCode),
                        onSubmitted: (v) {
                          final code = v.trim().toUpperCase();
                          if (code.length == 2) {
                            setState(() => _stateCode = code);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'center_truck',
            icon: const Icon(Icons.my_location),
            label: const Text('Center on Truck'),
            onPressed: () {
              final p = _lastTruckPos ?? center;
              _mapController.move(p, 12.0);
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'pause_resume',
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            label: Text(_paused ? 'Resume' : 'Pause'),
            onPressed: () {
              setState(() {
                _paused = !_paused;
              });
            },
          ),
        ],
      ),
    );
  }
}
