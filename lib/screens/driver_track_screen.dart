import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/driver_track_service.dart';

class DriverTrackScreen extends StatefulWidget {
  final String token;
  final DriverTrackService service;
  const DriverTrackScreen({
    super.key,
    required this.token,
    required this.service,
  });

  @override
  State<DriverTrackScreen> createState() => _DriverTrackScreenState();
}

class _DriverTrackScreenState extends State<DriverTrackScreen> {
  DriverTrackData? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.service.fetchByToken(widget.token);
      if (!mounted) return;
      setState(() {
        data = res;
        loading = false;
        if (res == null) error = 'Invalid or expired';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Failed to load';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Tracking')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : d == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('Driver ${d.driverId}'),
                    subtitle: Text(
                      d.activeLoad == null
                          ? 'No active load'
                          : 'Active: ${d.activeLoad!['origin']} → ${d.activeLoad!['destination']} • ${d.activeLoad!['status']}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Position',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (d.lat == null || d.lon == null)
                          const Text('No recent position')
                        else ...[
                          Text('Last update: ${d.recordedAt?.toLocal()}'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 260,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(d.lat!, d.lon!),
                                initialZoom: 10,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(d.lat!, d.lon!),
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        size: 36,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
