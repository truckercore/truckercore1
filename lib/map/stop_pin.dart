// lib/map/stop_pin.dart
// Model used for clustered map pins and scoring/transparency factors.

class StopPin {
  final String poiId;
  final String name;
  final double lat;
  final double lng;
  final double distanceMi;
  final String occupancy; // open/some/full/unknown
  final double confidence; // 0..1
  final int? fuelDiscountCents; // from promos, max-per-stop
  final double loyalty; // 0..1
  final double amenities; // 0..1

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

  Map<String, double> factors() => {
        'parking': _parkingScore(occupancy),
        'fuel': _fuelNorm(fuelDiscountCents),
        'loyalty': loyalty,
        'amenities': amenities,
        'distance': _distNorm(distanceMi),
        'confidence': confidence,
      };
}

// Normalizers
double _parkingScore(String occ) => switch (occ) {
      'open' => 1.0,
      'some' => 0.6,
      'full' => 0.1,
      _ => 0.4,
    };

double _fuelNorm(int? cents) => cents == null ? 0 : (cents.clamp(0, 20) / 20.0);

double _distNorm(double mi) => 1.0 / (1.0 + 0.2 * mi);
