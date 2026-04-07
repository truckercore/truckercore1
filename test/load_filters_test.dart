import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/loads/load_filters.dart';

void main() {
  group('LoadFilters.toQueryUtc + normalization', () {
    test('throws when only one of from/to is set', () {
      final lf = LoadFilters(pickupFromLocal: DateTime(2025));
      expect(() => lf.toQueryUtc(), throwsArgumentError);
    });

    test('normalizes local range to UTC start/end of days and validates', () {
      final from = DateTime(2025);
      final to = DateTime(2025, 1, 7);
      final lf = LoadFilters(
        status: LoadStatus.published,
        pickupFromLocal: from,
        pickupToLocal: to,
        origin: 'Columbus',
        destination: 'Chicago',
        equipment: 'dry_van',
        limit: 25,
      );
      final q = lf.toQueryUtc();
      expect(q['status'], 'published');
      expect(q['pickup_from_utc'], isNotNull);
      expect(q['pickup_to_utc'], isNotNull);
      final fromUtc = DateTime.parse(q['pickup_from_utc'] as String);
      final toUtc = DateTime.parse(q['pickup_to_utc'] as String);
      final norm = normalizeLocalDateRangeToUtc(from, to);
      expect(fromUtc, norm.start);
      expect(toUtc, norm.end);
      expect(q['origin'], 'Columbus');
      expect(q['destination'], 'Chicago');
      expect(q['equipment'], 'dry_van');
      expect(q['limit'], 25);
    });

    test('allows equal from==to (single day)', () {
      final d = DateTime(2025);
      final lf = LoadFilters(pickupFromLocal: d, pickupToLocal: d);
      final q = lf.toQueryUtc();
      expect(q['pickup_from_utc'], isNotNull);
      expect(q['pickup_to_utc'], isNotNull);
    });
  });
}
