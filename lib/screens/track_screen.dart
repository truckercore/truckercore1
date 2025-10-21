import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/track_service.dart';

class TrackScreen extends StatefulWidget {
  final String token;
  final TrackService service;

  const TrackScreen({super.key, required this.token, required this.service});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  TrackData? data;
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
        if (res == null) error = 'Invalid or expired tracking link.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Failed to load tracking.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      runSpacing: 12,
                      children: [
                        _kv('Origin', d.origin ?? '—'),
                        _kv('Destination', d.destination ?? '—'),
                        _kv('Status', (d.status ?? '—').toUpperCase()),
                        _kv('ETA', d.etaAt?.toLocal().toString() ?? '—'),
                        _kv('Pickup', d.pickupAt?.toLocal().toString() ?? '—'),
                        _kv(
                          'Dropoff',
                          d.dropoffAt?.toLocal().toString() ?? '—',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Driver Position',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (d.lat == null || d.lon == null)
                          const Text(
                            'No recent position available.',
                            style: TextStyle(color: Colors.black54),
                          )
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
                                  userAgentPackageName: 'com.yourcompany.app',
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

  Widget _kv(String k, String v) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
