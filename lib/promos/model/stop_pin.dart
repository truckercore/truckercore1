// lib/promos/model/stop_pin.dart
// StopPin model and scoring helpers for ranked recommendations.

class StopPin {
  final String poiId;
  final String name;
  final double lat;
  final double lng;
  final double distanceMi;
  final String occupancy; // open|some|full|unknown
  final double confidence; // 0..1
  final int? fuelDiscountCents; // best promo at this stop (amount off)
  final double loyalty; // 0..1 (user-brand affinity)
  final double amenities; // 0..1 (optional)
  const StopPin({
    required this.poiId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceMi,
    required this.occupancy,
    required this.confidence,
    this.fuelDiscountCents,
    this.loyalty = 0,
    this.amenities = 0,
  });
}

double _parkingScore(String occ) {
  switch (occ) {
    case 'open':
      return 1.0;
    case 'some':
      return 0.6;
    case 'full':
      return 0.1;
    default:
      return 0.4;
  }
}

double _fuelNorm(int? cents) => cents == null ? 0 : (cents.clamp(0, 20) / 20.0);

double _distNorm(double mi) => 1.0 / (1.0 + 0.2 * mi);

const _wParking = 0.35;
const _wFuel = 0.25;
const _wLoyalty = 0.15;
const _wAmen = 0.15;
const _wDist = 0.10;
const _wConf = 0.10;

double computeStopScore(StopPin s) {
  return _wParking * _parkingScore(s.occupancy) +
      _wFuel * _fuelNorm(s.fuelDiscountCents) +
      _wLoyalty * s.loyalty +
      _wAmen * s.amenities +
      _wDist * _distNorm(s.distanceMi) +
      _wConf * s.confidence;
}

Map<String, double> computeFactors(StopPin s) => {
      'parking': _parkingScore(s.occupancy),
      'fuel': _fuelNorm(s.fuelDiscountCents),
      'loyalty': s.loyalty,
      'amenities': s.amenities,
      'distance': _distNorm(s.distanceMi),
      'confidence': s.confidence,
    };
