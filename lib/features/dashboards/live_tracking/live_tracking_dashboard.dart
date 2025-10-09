import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/dashboards/base_dashboard.dart';
import '../services/dashboard_export.dart';

// Minimal vehicle model and provider to keep this dashboard self-contained.
class VehicleLocation {
  final double latitude;
  final double longitude;
  final String? city;
  const VehicleLocation({required this.latitude, required this.longitude, this.city});
}

class Vehicle {
  final String id;
  final String unitNumber;
  final String status; // active | idle | offline | maintenance
  final double? speed; // mph
  final String? driverName;
  final VehicleLocation? location;
  const Vehicle({
    required this.id,
    required this.unitNumber,
    required this.status,
    this.speed,
    this.driverName,
    this.location,
  });
}

// Expose a provider that can be overridden by the app with real data.
final liveTrackingVehiclesProvider = Provider<List<Vehicle>>((ref) {
  // Default empty list; app can override this provider globally to inject data.
  return const <Vehicle>[];
});

/// Mock vehicle count for demo/testing; can be overridden via ProviderScope overrides (e.g., from DashboardEntry window args).
final mockVehicleCountProvider = Provider<int>((ref) => 10);

// Stream provider emitting real-time vehicle updates.
// By default, if no data is injected via liveTrackingVehiclesProvider, it emits a mock moving fleet.
final liveTrackingVehiclesStreamProvider = StreamProvider<List<Vehicle>>((ref) async* {
  var tick = 0;
  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    final injected = ref.read(liveTrackingVehiclesProvider);
    if (injected.isNotEmpty) {
      // If the app overrides the static provider with data, just stream that as-is
      yield injected;
    } else {
      final count = ref.read(mockVehicleCountProvider);
      yield _mockVehicles(tick, count: count);
    }
    tick++;
  }
});

List<Vehicle> _mockVehicles(int tick, {int count = 10}) {
  // Procedurally generate a moving fleet across the continental US.
  // Positions are deterministic per index; movement is a slow drift over time.
  final t = tick.toDouble();
  const usaCenterLat = 39.8283;
  const usaCenterLon = -98.5795;

  Color statusColor(String s) => Colors.grey; // unused but placeholder

  String statusFor(int i, int tick) {
    const sts = ['active', 'idle', 'active', 'maintenance', 'active', 'offline'];
    return sts[(i + (tick ~/ 60)) % sts.length];
  }

  double mphFor(int i) {
    const base = [62.0, 0.0, 55.0, 0.0, 48.0, 0.0];
    return base[i % base.length];
  }

  // Distribute vehicles in concentric rings around USA center
  final list = <Vehicle>[];
  final n = count.clamp(1, 1000);
  for (var i = 0; i < n; i++) {
    final angle = (i / n) * 2 * math.pi;
    final ring = 5 + (i % 5) * 4; // degrees spread radius 5..21
    final baseLat = usaCenterLat + ring * 0.1 * math.sin(angle);
    final baseLon = usaCenterLon + ring * 0.1 * math.cos(angle);
    // Gentle drift
    final lat = baseLat + 0.02 * math.sin(t / 30.0 + i * 0.1);
    final lon = baseLon + 0.02 * math.cos(t / 30.0 + i * 0.07);
    final unit = 'TC${100 + i}';
    final id = 'veh_${i + 1}';
    list.add(
      Vehicle(
        id: id,
        unitNumber: unit,
        status: statusFor(i, tick),
        speed: mphFor(i),
        driverName: 'Driver ${unit.substring(0, unit.length >= 2 ? 2 : 1)}',
        location: VehicleLocation(latitude: lat, longitude: lon),
      ),
    );
  }
  return list;
}

class LiveTrackingDashboard extends BaseDashboard {
  const LiveTrackingDashboard({super.key})
      : super(
          config: const DashboardConfig(
            id: 'live_tracking',
            title: 'Live Fleet Tracking',
            defaultSize: Size(1920, 1080),
          ),
        );

  @override
  ConsumerState<LiveTrackingDashboard> createState() => _LiveTrackingDashboardState();

  @override
  Widget buildDashboard(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(liveTrackingVehiclesStreamProvider);

    return vehiclesAsync.when(
      data: (vehicles) => _LiveTrackingContent(vehicles: vehicles),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error loading tracking data', style: TextStyle(fontSize: 18, color: Colors.red[300])),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> onDashboardInit(WidgetRef ref) async {}

  @override
  Future<void> onDashboardDispose(WidgetRef ref) async {}
}

class _LiveTrackingDashboardState extends BaseDashboardState<LiveTrackingDashboard> {}

class _LiveTrackingContent extends StatefulWidget {
  final List<Vehicle> vehicles;
  const _LiveTrackingContent({required this.vehicles});

  @override
  State<_LiveTrackingContent> createState() => _LiveTrackingContentState();
}

class _LiveTrackingContentState extends State<_LiveTrackingContent> {
  final MapController _mapController = MapController();
  Vehicle? _selectedVehicle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _getInitialCenter(),
            initialZoom: 5.0,
            minZoom: 3.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.truckercore.app',
              maxZoom: 19,
            ),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
        Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
        Positioned(right: 0, top: 60, bottom: 0, width: 320, child: _buildVehicleSidebar()),
        Positioned(left: 16, top: 76, child: _buildStatusBadge()),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.map, color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Text('Live Fleet Tracking', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, snapshot) {
              final now = DateTime.now();
              return Text(
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500),
              );
            },
          ),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.download), onPressed: _exportVehicles, tooltip: 'Export to CSV'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {}), tooltip: 'Refresh'),
          IconButton(icon: const Icon(Icons.center_focus_strong), onPressed: _centerOnVehicles, tooltip: 'Center on Fleet'),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final activeCount = widget.vehicles.where((v) => v.status == 'active').length;
    final idleCount = widget.vehicles.where((v) => v.status == 'idle').length;
    final offlineCount = widget.vehicles.where((v) => v.status == 'offline').length;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(mainAxisSize: MainAxisSize.min, children: [
              _Dot(color: Colors.green),
              SizedBox(width: 8),
              Text('Active:', style: TextStyle(fontWeight: FontWeight.w500)),
            ]),
            Text('$activeCount'),
            const SizedBox(height: 8),
            const Row(mainAxisSize: MainAxisSize.min, children: [
              _Dot(color: Colors.orange),
              SizedBox(width: 8),
              Text('Idle:', style: TextStyle(fontWeight: FontWeight.w500)),
            ]),
            Text('$idleCount'),
            const SizedBox(height: 8),
            const Row(mainAxisSize: MainAxisSize.min, children: [
              _Dot(color: Colors.red),
              SizedBox(width: 8),
              Text('Offline:', style: TextStyle(fontWeight: FontWeight.w500)),
            ]),
            Text('$offlineCount'),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSidebar() {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Vehicles (${widget.vehicles.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Icon(Icons.local_shipping, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = widget.vehicles[index];
                final isSelected = _selectedVehicle?.id == vehicle.id;
                return ListTile(
                  selected: isSelected,
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(vehicle.status),
                    child: Text(vehicle.unitNumber.substring(0, vehicle.unitNumber.length >= 2 ? 2 : 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(vehicle.unitNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(vehicle.driverName ?? 'No driver', style: TextStyle(color: Colors.grey[400])),
                    if (vehicle.location != null)
                      Text(vehicle.location!.city ?? '--', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ]),
                  trailing: vehicle.speed != null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(vehicle.speed!.toStringAsFixed(0), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('mph', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ])
                      : Text('--', style: TextStyle(color: Colors.grey[600])),
                  onTap: () {
                    setState(() => _selectedVehicle = vehicle);
                    _centerOnVehicle(vehicle);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return widget.vehicles.where((v) => v.location != null).map((vehicle) {
      final location = vehicle.location!;
      final isSelected = _selectedVehicle?.id == vehicle.id;
      return Marker(
        point: LatLng(location.latitude, location.longitude),
        width: isSelected ? 100 : 80,
        height: isSelected ? 100 : 80,
        child: GestureDetector(
          onTap: () => setState(() => _selectedVehicle = vehicle),
          child: _buildMarkerWidget(vehicle, isSelected),
        ),
      );
    }).toList();
  }

  Widget _buildMarkerWidget(Vehicle vehicle, bool isSelected) {
    final statusColor = _getStatusColor(vehicle.status);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 5,
          top: 5,
          child: Container(
            width: isSelected ? 48 : 40,
            height: isSelected ? 48 : 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        Center(
          child: Container(
            width: isSelected ? 48 : 40,
            height: isSelected ? 48 : 40,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: isSelected ? 4 : 3),
              boxShadow: [
                BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: isSelected ? 12 : 8, spreadRadius: isSelected ? 3 : 2),
              ],
            ),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
          ),
        ),
        if (isSelected)
          Positioned(
            top: isSelected ? 55 : 45,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  vehicle.unitNumber,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  LatLng _getInitialCenter() {
    final withLoc = widget.vehicles.where((v) => v.location != null).toList();
    if (withLoc.isEmpty) {
      return const LatLng(39.8283, -98.5795); // USA center
    }
    double latSum = 0, lonSum = 0;
    for (final v in withLoc) {
      latSum += v.location!.latitude;
      lonSum += v.location!.longitude;
    }
    return LatLng(latSum / withLoc.length, lonSum / withLoc.length);
  }

  void _centerOnVehicle(Vehicle vehicle) {
    if (vehicle.location != null) {
      _mapController.move(LatLng(vehicle.location!.latitude, vehicle.location!.longitude), 12.0);
    }
  }

  void _centerOnVehicles() {
    _mapController.move(_getInitialCenter(), 5.0);
  }

  Future<void> _exportVehicles() async {
    try {
      final csv = await generateCSV(widget.vehicles);
      final path = await saveToDisk('fleet_overview', csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported CSV to: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'idle':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      case 'maintenance':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
