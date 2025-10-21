// lib/widgets/ad_banner.dart
// Simple ad banner widget using AdsService with graceful empty/failed states and dismiss support.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ads_service.dart';

class AdBanner extends StatefulWidget {
  final AdsService service;
  final double lat;
  final double lng;
  final String role;
  final String? deviceHash;
  final double radiusKm;

  const AdBanner({
    super.key,
    required this.service,
    required this.lat,
    required this.lng,
    this.role = 'driver',
    this.deviceHash,
    this.radiusKm = 25,
  });

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  bool loading = true;
  String? error;
  AdItem? ad;
  bool dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final items = await widget.service.fetchNearbyAds(
        lat: widget.lat,
        lng: widget.lng,
        role: widget.role,
        deviceHash: widget.deviceHash,
        radiusKm: widget.radiusKm,
      );
      if (!mounted) return;
      setState(() {
        ad = items.isNotEmpty ? items.first : null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _openCta(AdItem ad) async {
    await widget.service.recordClick(ad, deviceHash: widget.deviceHash);
    final urlStr = ad.ctaUrl;
    if (urlStr == null || urlStr.isEmpty) return;
    final uri = Uri.tryParse(urlStr);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link')),
      );
    }
    try { HapticFeedback.selectionClick(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (loading || dismissed) return const SizedBox.shrink();
    if (error != null || ad == null) {
      // Non-blocking placeholder to avoid empty gap
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox.shrink(),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: (ad!.mediaUrl != null && ad!.mediaUrl!.startsWith('http'))
            ? Image.network(ad!.mediaUrl!, width: 64, height: 64, fit: BoxFit.cover)
            : const Icon(Icons.local_gas_station),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ad!.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6)),
              child: const Text('Sponsored', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        subtitle: Text(ad!.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ad!.ctaText != null)
              ElevatedButton(
                onPressed: () => _openCta(ad!),
                child: Text(ad!.ctaText!),
              ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: () => setState(() => dismissed = true),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        onTap: () => _openCta(ad!),
      ),
    );
  }
}
