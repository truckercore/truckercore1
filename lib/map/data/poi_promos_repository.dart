// lib/map/data/poi_promos_repository.dart
// Fetches /state.parking (bbox) and /promotions.nearby (lat,lng), merges into StopPin list.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../common/config/app_env.dart';
import '../stop_pin.dart';

class PoiPromosRepository {
  PoiPromosRepository({http.Client? client, this.getAuthToken}) : _client = client ?? http.Client();

  final http.Client _client;
  final FutureOr<String?> Function()? getAuthToken; // return 'Bearer ...' or null

  // Simple in-memory cache keyed by bbox string
  final Map<String, _CacheEntry> _cache = {};

  // Debounce controller per key
  Timer? _debounce;

  Future<List<StopPin>> fetchPins({
    required double userLat,
    required double userLng,
    required ({double west, double south, double east, double north}) bbox,
    double minConf = 0.0,
  }) async {
    final bboxStr = '${bbox.west},${bbox.south},${bbox.east},${bbox.north}';

    // Serve from cache if fresh (< 10s)
    final now = DateTime.now();
    final ce = _cache[bboxStr];
    if (ce != null && now.difference(ce.at).inSeconds < 10) {
      return ce.pins;
    }

    // Compose URLs
    final base = AppEnv.supabaseUrl.replaceAll(RegExp(r'/+$'), '');
    final parkingUrl = Uri.parse('$base/functions/v1/state.parking?bbox=$bboxStr&min_conf=$minConf');
    final promosUrl = Uri.parse('$base/functions/v1/promotions.nearby?lat=$userLat&lng=$userLng&radius_mi=${_radiusMiFromBbox(userLat, bbox)}');

    final headers = <String, String>{'content-type': 'application/json'};
    final tok = await getAuthToken?.call();
    if (tok != null && tok.isNotEmpty) headers['authorization'] = tok;

    final results = await Future.wait([
      _client.get(parkingUrl, headers: headers),
      _client.get(promosUrl, headers: headers),
    ]);

    final parkingBody = _json(results[0]);
    final promosBody = _json(results[1]);
    final parkingItems = (parkingBody['items'] as List? ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .toList(growable: false);
    final promos = (promosBody['promos'] as List? ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .toList(growable: false);

    // Build StopPin map by poi_id
    final byPoi = <String, StopPin>{};
    for (final s in parkingItems) {
      final poiId = (s['poi_id'] ?? '').toString();
      if (poiId.isEmpty) continue;
      final name = (s['name'] ?? '') as String? ?? '';
      final lat = (s['lat'] as num).toDouble();
      final lng = (s['lng'] as num).toDouble();
      final distMi = _haversineMi(userLat, userLng, lat, lng);
      final occ = (s['occupancy'] ?? 'unknown').toString();
      final conf = ((s['confidence'] as num?) ?? 0).toDouble();
      byPoi[poiId] = StopPin(
        poiId: poiId,
        name: name,
        lat: lat,
        lng: lng,
        distanceMi: double.parse(distMi.toStringAsFixed(1)),
        occupancy: occ,
        confidence: conf.clamp(0, 1),
      );
    }

    // Attach best fuel discount and loyalty per stop from promotions
    for (final p in promos) {
      final locationId = (p['location_id'] ?? '').toString();
      // location_id should equal poi_id for join in our schema; if different, skip
      final pin = byPoi[locationId];
      if (pin == null) continue;
      final brand = (p['brand'] ?? '').toString().toLowerCase();
      // naive loyalty heuristic: if brand present, mark as 1.0 for demo; real app would look up prefs
      final loyalty = brand.isNotEmpty ? 1.0 : 0.0;
      final type = (p['type'] ?? '').toString();
      final valueCents = (p['value_cents'] as num?)?.toInt();
      final fuelCents = type == 'amount' ? (valueCents ?? 0) : null;
      byPoi[pin.poiId] = StopPin(
        poiId: pin.poiId,
        name: pin.name,
        lat: pin.lat,
        lng: pin.lng,
        distanceMi: pin.distanceMi,
        occupancy: pin.occupancy,
        confidence: pin.confidence,
        fuelDiscountCents: max(pin.fuelDiscountCents ?? 0, fuelCents ?? 0),
        loyalty: max(pin.loyalty, loyalty),
        amenities: pin.amenities,
      );
    }

    final pins = byPoi.values.toList(growable: false);
    _cache[bboxStr] = _CacheEntry(pins: pins, at: DateTime.now());
    return pins;
  }

  // Simple debounce wrapper. Returns a future that completes after delay.
  Future<void> debounce([Duration delay = const Duration(milliseconds: 350)]) async {
    final c = Completer<void>();
    _debounce?.cancel();
    _debounce = Timer(delay, () => c.complete());
    return c.future;
  }

  static Map<String, dynamic> _json(http.Response r) {
    if (r.statusCode == 304) return const {};
    try {
      return json.decode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  static double _radiusMiFromBbox(double lat, ({double west, double south, double east, double north}) bbox) {
    // Approximate radius as half of the diagonal of bbox, in miles
    final lat1 = bbox.south, lng1 = bbox.west;
    final lat2 = bbox.north, lng2 = bbox.east;
    return _haversineMi((lat1 + lat2) / 2, lat, (lng1 + lng2) / 2, lat) +
        _haversineMi(lat1, lng1, lat2, lng2) / 2;
  }

  static double _haversineMi(double lat1, double lng1, double lat2, double lng2) {
    const R = 3958.8; // Earth radius in miles
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) + cos(_toRad(lat1)) * cos(_toRad(lat2)) * (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double x) => x * pi / 180.0;
}

class _CacheEntry {
  final List<StopPin> pins;
  final DateTime at;
  _CacheEntry({required this.pins, required this.at});
}
