import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final _sb = Supabase.instance.client;

/// Fetch nearby ads via Edge Function "ads-nearby".
/// Parameters:
/// - lat/lng: current location
/// - role: e.g., 'driver' | 'owner' (server may use to filter)
/// - radiusKm: targeting radius in kilometers
Future<List<Map<String, dynamic>>> fetchAdsNearby({
  required double lat,
  required double lng,
  String role = 'driver',
  double radiusKm = 25,
}) async {
  final res = await _sb.functions.invoke(
    'ads-nearby',
    body: {
      'lat': lat,
      'lng': lng,
      'role': role,
      'radius_km': radiusKm,
    },
  );
  final data = res.data as List<dynamic>? ?? const [];
  return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

/// A compact, single-banner ad card suitable for dashboard placement.
/// Shows a single ad (first returned) with a Sponsored label and CTA.
class TruckstopAdBanner extends StatefulWidget {
  final double lat;
  final double lng;
  final String role; // default 'driver'
  final double radiusKm; // default 25
  const TruckstopAdBanner({
    super.key,
    required this.lat,
    required this.lng,
    this.role = 'driver',
    this.radiusKm = 25,
  });

  @override
  State<TruckstopAdBanner> createState() => _TruckstopAdBannerState();
}

class _TruckstopAdBannerState extends State<TruckstopAdBanner> {
  Map<String, dynamic>? _ad;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ads = await fetchAdsNearby(
        lat: widget.lat,
        lng: widget.lng,
        role: widget.role,
        radiusKm: widget.radiusKm,
      );
      if (!mounted) return;
      setState(() {
        _ad = ads.isNotEmpty ? ads.first : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 76,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_ad == null) return const SizedBox.shrink();

    final title = _ad!['title'] as String? ?? 'Special Offer';
    final body = _ad!['body'] as String? ?? '';
    final cta = _ad!['cta_text'] as String? ?? 'View';
    final url = _ad!['cta_url'] as String?;
    final icon = (_ad!['icon'] as String?) ?? 'fuel'; // optional

    IconData leadingIcon;
    switch (icon) {
      case 'food':
        leadingIcon = Icons.restaurant;
        break;
      case 'wash':
        leadingIcon = Icons.local_car_wash;
        break;
      case 'fuel':
      default:
        leadingIcon = Icons.local_gas_station;
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Sponsored', style: TextStyle(fontSize: 10, color: Colors.amber)),
          ],
        ),
        title: Row(
          children: [
            Icon(leadingIcon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(
          onPressed: () => _openUrl(url),
          child: Text(cta),
        ),
        onTap: () => _openUrl(url),
      ),
    );
  }
}
