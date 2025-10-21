import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  Future<void> _invokeFunction(BuildContext context, String name, Map<String, dynamic> body) async {
    final supa = Supabase.instance.client;
    try {
      final resp = await supa.functions.invoke(name, body: body);
      if (!context.mounted) return;
      if (resp.data != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Success: ${name.replaceAll('-', ' ')}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No data returned from $name')),
        );
      }
    } on FunctionException catch (e) {
      if (!context.mounted) return;
      if (e.status == 402) {
        final upgradeUrl = e.details is Map<String, dynamic> ? (e.details['upgrade_url'] as String?) : null;
        _showUpgradeDialog(context, upgradeUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ($name): ${e.toString()}')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    }
  }

  void _showUpgradeDialog(BuildContext context, String? url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Premium Required'),
        content: const Text('This feature is part of TruckerCore Premium. Upgrade to unlock.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (url != null) {
                // In a real app, launch URL
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Open upgrade: $url')),
                );
              }
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Road Assistant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            const PremiumUpgradeBanner(),
            const SizedBox(height: 8),
            const _Title('Route & Navigation'),
            DashboardCard(
              Icons.alt_route,
              'Plan Truck-Safe Route',
              'Legal clearances, + POIs',
              onTap: () => _invokeFunction(context, 'routing-summary', {
                'driver_id': 'demo-driver',
                'origin': {'lat': 41.88, 'lng': -87.63},
                'destination': {'lat': 34.05, 'lng': -118.24},
                'hazmat': false,
              }),
            ),
            DashboardCard(
              Icons.map,
              'Realtime Map+Fuel',
              'Diesel prices/parking on the route',
              onTap: () => _invokeFunction(context, 'fuel-optimization', {
                'driver_id': 'demo-driver',
                'route_gpx': {'mock': true},
                'fuel_type': 'diesel',
              }),
            ),
            const _Title('Community/Live Updates'),
            const ParkingReportButton(),
            const DashboardCard(Icons.outlet, 'Truck Stop Reviews', 'Read/add real feedback, photos'),
            const _Title('Convenience/Loyalty'),
            const DashboardCard(Icons.loyalty, 'Loyalty Wallet', 'Points, showers, mobile pay at pump'),
            const DashboardCard(Icons.shopping_cart, 'Shower/Parking Booking', 'Reserve via app, receipt auto-logged'),
            const _Title('Business & Compliance'),
            const DashboardCard(Icons.work, 'Marketplace Loads', 'One-tap in-app booking'),
            const DashboardCard(Icons.assignment, 'Logbook (HOS)', 'Digital logs, IFTA-ready'),
            const _Title('AI & Assistant'),
            const RoadDoggAICard(),
          ],
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  const DashboardCard(this.icon, this.title, this.subtitle, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: Colors.indigo),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: onTap,
        ),
      );
}

class _Title extends StatelessWidget {
  final String t;
  const _Title(this.t);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 5),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)));
}

class RoadDoggAICard extends StatefulWidget {
  const RoadDoggAICard({super.key});
  @override
  State<RoadDoggAICard> createState() => _RoadDoggAICardState();
}

class _RoadDoggAICardState extends State<RoadDoggAICard> {
  final _controller = TextEditingController();
  String _response = '';
  @override
  Widget build(BuildContext context) => Card(
        color: Colors.indigo.shade50,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const Text('Ask RoadDogg (AI)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'What’s the best place to stop for fuel on I-80?'),
                onSubmitted: (query) async {
                  setState(() => _response = 'Thinking...');
                  await Future.delayed(const Duration(seconds: 1));
                  setState(() => _response = 'AI: TA exit 322, diesel \$4.09, plenty parking (3 left)');
                },
              ),
              if (_response.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_response, style: TextStyle(color: Colors.indigo[900])),
                ),
            ],
          ),
        ),
      );
}

// --- Additional UI widgets: Premium banner and Parking report with cooldown ---

class PremiumUpgradeBanner extends StatefulWidget {
  const PremiumUpgradeBanner({super.key});
  @override
  State<PremiumUpgradeBanner> createState() => _PremiumUpgradeBannerState();
}

class _PremiumUpgradeBannerState extends State<PremiumUpgradeBanner> {
  static const _prefKey = 'premium_banner_dismissed';
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _hidden = sp.getBool(_prefKey) ?? false);
  }

  Future<void> _dismiss() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_prefKey, true);
    if (!mounted) return;
    setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    return Card(
      color: Colors.amber.shade50,
      child: ListTile(
        leading: const Icon(Icons.stars, color: Colors.amber),
        title: const Text('Unlock Premium features'),
        subtitle: const Text('Fuel optimization, smart routing, parking heatmaps, and more.'),
        trailing: Wrap(spacing: 8, children: [
          TextButton(onPressed: _dismiss, child: const Text('Dismiss')),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open upgrade: https://truckercore.app/upgrade')),
              );
            },
            child: const Text('Upgrade'),
          ),
        ]),
      ),
    );
  }
}

class ParkingReportButton extends StatefulWidget {
  const ParkingReportButton({super.key});
  @override
  State<ParkingReportButton> createState() => _ParkingReportButtonState();
}

class _ParkingReportButtonState extends State<ParkingReportButton> {
  static const cooldownSec = 600; // 10 min
  static const _prefKeyUntil = 'parking_report_cooldown_until';
  int _remaining = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadCooldown() async {
    final sp = await SharedPreferences.getInstance();
    final untilMs = sp.getInt(_prefKeyUntil) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final left = ((untilMs - now) / 1000).ceil();
    if (left > 0) {
      setState(() => _remaining = left);
      _startTicker();
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        setState(() => _remaining = 0);
        t.cancel();
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  Future<String> _computeDeviceHash() async {
    try {
      final info = DeviceInfoPlugin();
      final b = StringBuffer();
      if (Theme.of(context).platform == TargetPlatform.android) {
        final a = await info.androidInfo;
        b.write('${a.id}|${a.brand}|${a.device}|${a.model}');
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final i = await info.iosInfo;
        b.write('${i.identifierForVendor}|${i.model}');
      } else {
        final w = await info.windowsInfo;
        b.write('${w.deviceId}|${w.computerName}');
      }
      final bytes = utf8.encode(b.toString());
      return crypto.sha256.convert(bytes).toString().substring(0, 16);
    } catch (_) {
      return 'unknown-device';
    }
  }

  Future<void> _report() async {
    if (_remaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cooldown active. Retry in ${_remaining}s')),
      );
      return;
    }

    final deviceHash = await _computeDeviceHash();
    try {
      final supa = Supabase.instance.client;
      final resp = await supa.functions.invoke('parking-report-update',
          body: {
            'poi_id': 'demo-poi',
            'driver_id': 'demo-driver',
            'available_spots': 5,
            'confidence': 70,
            'is_premium': false,
            'device_hash': deviceHash,
          },
          headers: {'X-Device-Hash': deviceHash});
      if (!mounted) return;
      if (resp.data != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for the report!')),
        );
        final sp = await SharedPreferences.getInstance();
        final until = DateTime.now().millisecondsSinceEpoch + cooldownSec * 1000;
        await sp.setInt(_prefKeyUntil, until);
        if (!mounted) return;
        setState(() => _remaining = cooldownSec);
        _startTicker();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No response from server')),
        );
      }
    } on FunctionException catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report failed: $msg')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _remaining > 0
        ? 'Parking Report (retry in ${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')})'
        : 'Parking Report (crowd)';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_parking),
        title: Text(label),
        subtitle: const Text('Report real availability. Cooldown limits spam.'),
        trailing: FilledButton(
          onPressed: _report,
          child: const Text('Report'),
        ),
      ),
    );
  }
}
