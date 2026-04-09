import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

const String baseUrl = 'https://truckercore12.vercel.app';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> alerts = [];
  bool loading = true;

  String get _authToken =>
      Supabase.instance.client.auth.currentSession?.accessToken ?? '';

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/alerts?limit=30'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );
      final data = jsonDecode(res.body);
      setState(() { alerts = data['events'] ?? []; });
    } catch (_) {
    } finally {
      setState(() => loading = false);
    }
  }

  Color _alertColor(String type) {
    switch (type) {
      case 'hazard': return const Color(0xFFEF4444);
      case 'inspection': return const Color(0xFF3B82F6);
      case 'hos': return const Color(0xFFEAB308);
      case 'reroute': return const Color(0xFFF97316);
      case 'geofence': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF6B7280);
    }
  }

  String _alertIcon(String type) {
    switch (type) {
      case 'hazard': return '⚠️';
      case 'inspection': return '🚔';
      case 'hos': return '⏱️';
      case 'reroute': return '🔄';
      case 'geofence': return '📍';
      default: return '🔔';
    }
  }

  String _timeAgo(String timestamp) {
    final diff = DateTime.now().difference(DateTime.parse(timestamp));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alerts', style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
                    Text('Hazards, HOS, inspections',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                  onPressed: loadAlerts,
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : alerts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('✅', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text('No alerts', style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                            Text('All clear in last 24 hours',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadAlerts,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: alerts.length,
                          itemBuilder: (context, index) {
                            final alert = alerts[index];
                            final type = alert['type'] ?? 'notification';
                            final color = _alertColor(type);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_alertIcon(type),
                                    style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          alert['title'] ?? '',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (alert['body'] != null)
                                          Text(
                                            alert['body'],
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(alert['created_at'] ?? ''),
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}