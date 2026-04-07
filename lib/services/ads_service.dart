// lib/services/ads_service.dart
// Nearby ads client with coarse location+role keyed cache and local frequency caps.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'edge_client.dart';

class AdItem {
  final String id;
  final String? stopId;
  final String title;
  final String body;
  final String? mediaUrl;
  final String? ctaText;
  final String? ctaUrl;
  final String? trackingToken;

  const AdItem({
    required this.id,
    required this.title,
    required this.body,
    this.stopId,
    this.mediaUrl,
    this.ctaText,
    this.ctaUrl,
    this.trackingToken,
  });

  factory AdItem.fromJson(Map<String, dynamic> j) => AdItem(
        id: (j['id'] ?? '').toString(),
        stopId: j['stop_id']?.toString(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        mediaUrl: j['media_url']?.toString(),
        ctaText: j['cta_text']?.toString(),
        ctaUrl: j['cta_url']?.toString(),
        trackingToken: j['tracking_token']?.toString(),
      );
}

class AdsService {
  final EdgeClient edge;
  AdsService(this.edge);

  final Map<String, List<AdItem>> _cacheByKey = {};
  final Map<String, DateTime> _cacheAtByKey = {};

  String _key(double lat, double lng, String role) {
    // 1 km grid to avoid over-fragmentation
    final clat = (lat * 100).round() / 100;
    final clng = (lng * 100).round() / 100;
    return '$clat:$clng:$role';
  }

  Future<List<AdItem>> fetchNearbyAds({
    required double lat,
    required double lng,
    required String role,
    String? deviceHash,
    Duration cacheFor = const Duration(minutes: 15),
    double radiusKm = 25,
  }) async {
    final k = _key(lat, lng, role);
    final now = DateTime.now();
    final cachedAt = _cacheAtByKey[k];
    if (_cacheByKey[k] != null && cachedAt != null && now.difference(cachedAt) < cacheFor) {
      return _cacheByKey[k]!;
    }
    final resp = await edge.get('ads-nearby', {
      'lat': '$lat',
      'lng': '$lng',
      'role': role,
      'radius_km': '$radiusKm',
      if (deviceHash != null && deviceHash.isNotEmpty) 'device_hash': deviceHash,
    });
    // Edge function may return either a top-level array or a wrapped object { ads: [...] }.
    final List anyList = (resp['ads'] as List?) ?? (resp['data'] as List?) ?? const [];
    final list = anyList
        .map((e) => AdItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    final filtered = <AdItem>[];
    for (final ad in list) {
      if (await _underCap(ad.id, maxPerDay: 5) && await _cooldownOk(ad.id, minutes: 15)) {
        filtered.add(ad);
      }
    }

    _cacheByKey[k] = filtered;
    _cacheAtByKey[k] = now;
    return filtered;
  }

  Future<void> recordClick(AdItem ad, {String? deviceHash}) async {
    try {
      await edge.post('ad_click', {
        'ad_id': ad.id,
        if (ad.trackingToken != null) 'tracking_token': ad.trackingToken,
        if (deviceHash != null) 'device_hash': deviceHash,
      });
    } catch (_) {
      // ignore
    }
  }

  // Frequency capping helpers
  Future<bool> _underCap(String adId, {required int maxPerDay}) async {
    final prefs = await SharedPreferences.getInstance();
    final dayKey = _dayKey();
    final key = 'adcount:$dayKey:$adId';
    final count = prefs.getInt(key) ?? 0;
    if (count >= maxPerDay) return false;
    await prefs.setInt(key, count + 1);
    return true;
  }

  Future<bool> _cooldownOk(String adId, {required int minutes}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'adcool:$adId';
    final last = prefs.getInt(key);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < minutes * 60 * 1000) return false;
    await prefs.setInt(key, now);
    return true;
  }

  String _dayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month}-${now.day}';
  }
}
