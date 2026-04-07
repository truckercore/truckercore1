// lib/promos/state/pins_provider.dart
import 'dart:math' show max, sin, cos, sqrt, atan2;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../model/stop_pin.dart';

// Inputs you’ll wire to your networking layer
typedef ParkingStateRow = Map<String, dynamic>; // expects {poi_id,name,lat,lng,occupancy,confidence}
typedef PromoItem = Map<String, dynamic>; // expects {location_id,type,value_cents,brand}

final userLoyaltyBrandsProvider = Provider<Set<String>>((_) => const {});
final userLocationProvider = Provider<LatLng?>((_) => null);

class PinsResult {
  final List<StopPin> pins;
  final StopPin? best;
  const PinsResult(this.pins, this.best);
}

final pinsProvider = FutureProvider<PinsResult>((ref) async {
  final userLoc = ref.watch(userLocationProvider);
  if (userLoc == null) return const PinsResult([], null);

  // Fetch raw data
  final parking = await fetchParkingStateBbox(userLoc); // implement
  final promos = await fetchPromosNearby(userLoc); // implement
  final loyalty = ref.watch(userLoyaltyBrandsProvider);

  final byPoi = <String, StopPin>{};
  for (final row in parking) {
    final lat = (row['lat'] as num).toDouble();
    final lng = (row['lng'] as num).toDouble();
    final distMi = _distanceMi(userLoc.latitude, userLoc.longitude, lat, lng);
    byPoi[row['poi_id'] as String] = StopPin(
      poiId: row['poi_id'] as String,
      name: (row['name'] as String?) ?? 'Stop',
      lat: lat,
      lng: lng,
      distanceMi: distMi,
      occupancy: (row['occupancy'] as String?) ?? 'unknown',
      confidence: ((row['confidence'] as num?) ?? 0.5).toDouble(),
    );
  }

  for (final p in promos) {
    final poiId = p['location_id'] as String?;
    if (poiId == null) continue;
    final exist = byPoi[poiId];
    if (exist == null) continue;
    final brand = p['brand'] as String?;
    final loyaltyW = brand != null && loyalty.contains(brand) ? 1.0 : 0.0;
    final type = p['type'] as String?;
    final valueCents = (type == 'amount') ? (p['value_cents'] as int? ?? 0) : null;

    byPoi[poiId] = StopPin(
      poiId: exist.poiId,
      name: exist.name,
      lat: exist.lat,
      lng: exist.lng,
      distanceMi: exist.distanceMi,
      occupancy: exist.occupancy,
      confidence: exist.confidence,
      fuelDiscountCents: max(exist.fuelDiscountCents ?? 0, valueCents ?? 0),
      loyalty: max(exist.loyalty, loyaltyW),
      amenities: exist.amenities,
    );
  }

  final pins = byPoi.values.toList();
  pins.sort((a, b) => computeStopScore(b).compareTo(computeStopScore(a)));
  final best = pins.isEmpty ? null : pins.first;
  return PinsResult(pins, best);
});

// Haversine (mi)
double _distanceMi(double lat1, double lon1, double lat2, double lon2) {
  const R = 3958.8;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = (sin(dLat / 2) * sin(dLat / 2)) +
      (cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2));
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _deg2rad(double d) => d * 3.141592653589793 / 180.0;

// Stubs (replace with your networking)
Future<List<ParkingStateRow>> fetchParkingStateBbox(LatLng userLoc) async => <ParkingStateRow>[];
Future<List<PromoItem>> fetchPromosNearby(LatLng userLoc) async => <PromoItem>[];
