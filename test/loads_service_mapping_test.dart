import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/common/services/loads_service.dart';

void main() {
  test('LoadItem.fromMap maps fields safely', () {
    final row = {
      'id': 'abc',
      'origin': 'Columbus, OH',
      'destination': 'Chicago, IL',
      'pickup_at': '2025-09-04T10:00:00Z',
      'dropoff_at': '2025-09-05T10:00:00Z',
      'status': 'posted',
      'assigned_driver_id': null,
      'revenue_cents': 12345,
      'fuel_cents': 0,
      'tolls_cents': 0,
      'maintenance_cents': 0,
      'wage_cents': 0,
      'vehicle_type': 'dry_van',
      'origin_lat': 40.0,
      'origin_lon': -83.0,
      'posted_rate_usd_per_mi': 2.25,
      'estimated_miles': 500,
    };
    final item = LoadItem.fromMap(row);
    expect(item.id, 'abc');
    expect(item.origin, contains('Columbus'));
    expect(item.postedRateUsdPerMi, 2.25);
    expect(item.estimatedMiles, 500);
    expect(item.revenueCents, 12345);
  });
}
