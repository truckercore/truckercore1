import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../services/gps_tracking_service.dart';

const String baseUrl = 'https://truckercore12.vercel.app';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final gps = GpsTrackingService();

  bool tripActive = false;
  bool loading = false;
  String? tripId;
  String? errorMsg;
  DateTime? tripStartTime;

  String get _authToken =>
      Supabase.instance.client.auth.currentSession?.accessToken ?? '';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_authToken',
  };

  Future<void> startTrip() async {
    setState(() { loading = true; errorMsg = null; });

    try {
      await gps.startTracking();

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition();
      } catch (_) {}

      final res = await http.post(
        Uri.parse('$baseUrl/api/trips/start'),
        headers: _headers,
        body: jsonEncode({
          'startLat': pos?.latitude,
          'startLng': pos?.longitude,
          'startAddress': 'Driver Mobile Start',
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['trip'] != null) {
        setState(() {
          tripId = data['trip']['id'];
          tripActive = true;
          tripStartTime = DateTime.now();
        });
      } else {
        throw Exception(data['error'] ?? 'Failed to start trip');
      }
    } catch (e) {
      setState(() { errorMsg = e.toString(); });
      await gps.stopTracking();
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> endTrip() async {
    if (tripId == null) return;
    setState(() { loading = true; errorMsg = null; });

    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition();
      } catch (_) {}

      final res = await http.post(
        Uri.parse('$baseUrl/api/trips/end'),
        headers: _headers,
        body: jsonEncode({
          'tripId': tripId,
          'endLat': pos?.latitude,
          'endLng': pos?.longitude,
          'endAddress': 'Driver Mobile End',
          'tollCost': 0,
        }),
      );

      final data = jsonDecode(res.body);
      await gps.stopTracking();

      if (data['summary'] != null) {
        final summary = data['summary'];
        if (mounted) {
          _showTripSummary(summary);
        }
      }

      setState(() {
        tripId = null;
        tripActive = false;
        tripStartTime = null;
      });
    } catch (e) {
      setState(() { errorMsg = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  void _showTripSummary(Map summary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ Trip Completed',
              style: TextStyle(
                color: Color(0xFF4ADE80),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Expenses logged automatically',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            _SummaryRow('Miles driven', '${summary['miles']} mi'),
            _SummaryRow('Fuel cost', '\$${summary['fuelCost']}'),
            _SummaryRow('Toll cost', '\$${summary['tollCost']}'),
            _SummaryRow('Total expense', '\$${summary['totalCost']}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration() {
    if (tripStartTime == null) return '0:00';
    final diff = DateTime.now().difference(tripStartTime!);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Trip Tracker',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Miles, fuel & tolls auto-logged for taxes',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 24),

            // Status card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tripActive
                    ? const Color(0xFF14532D).withOpacity(0.5)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: tripActive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF334155),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tripActive
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tripActive ? 'Trip Active' : 'No Active Trip',
                        style: TextStyle(
                          color: tripActive
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  if (tripActive) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatChip('⏱️', _formatDuration()),
                        const SizedBox(width: 8),
                        _StatChip('📍', 'GPS active'),
                        const SizedBox(width: 8),
                        _StatChip('⛽', 'Tracking'),
                      ],
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Start a trip to begin tracking miles and expenses',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),

            if (errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  errorMsg!,
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                ),
              ),
            ],

            const Spacer(),

            if (!tripActive)
              ElevatedButton.icon(
                onPressed: loading ? null : startTrip,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  loading ? 'Starting...' : 'Start Trip',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: loading ? null : endTrip,
                icon: const Icon(Icons.stop),
                label: Text(
                  loading ? 'Calculating...' : 'End Trip & Log Expenses',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),

            const SizedBox(height: 8),
            const Text(
              'Fuel, tolls & miles are automatically added to your expenses for tax reporting',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF475569), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  const _StatChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$icon $label',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
          Text(value, style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }
}