import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/loads/dto/load_filter_dto.dart';
import 'package:truckercore1/features/loads/load_filters.dart';

void main() {
  group('LoadFilters -> LoadFilterDto mapping', () {
    test('maps local date range to UTC ISO with full-day bounds', () {
      final localFrom = DateTime(2025, 1, 15);
      final localTo = DateTime(2025, 1, 17);
      final f = LoadFilters(
        status: LoadStatus.published,
        pickupFromLocal: localFrom,
        pickupToLocal: localTo,
        origin: 'Columbus, OH',
        destination: 'Nashville, TN',
        equipment: 'dry_van',
        limit: 25,
        cursor: 'abc',
      );
      final dto = f.toDto();
      expect(dto.status, 'published');
      expect(dto.origin, 'Columbus, OH');
      expect(dto.destination, 'Nashville, TN');
      expect(dto.equipment, 'dry_van');
      expect(dto.limit, 25);
      expect(dto.cursor, 'abc');

      // Verify UTC conversion under normalizeLocalDateRangeToUtc
      final q = f.toQueryUtc();
      final utcFrom = DateTime.parse(q['pickup_from_utc'] as String);
      final utcTo = DateTime.parse(q['pickup_to_utc'] as String);
      // Expect UTC values and inclusive range; hour varies by local timezone
      expect(utcFrom.isUtc, isTrue);
      expect(utcTo.isUtc, isTrue);
      expect(utcFrom.isBefore(utcTo) || utcFrom.isAtSameMomentAs(utcTo), isTrue);

      // dto must equal query utc values
      expect(dto.pickupFrom, q['pickup_from_utc']);
      expect(dto.pickupTo, q['pickup_to_utc']);
    });

    test('cursor tuple json roundtrip', () {
      final tup = LoadCursorTuple(pickupAt: DateTime.utc(2025, 01, 02, 03, 04, 05), id: 'L123');
      final json = tup.toJson();
      final back = LoadCursorTuple.fromJson(json);
      expect(back.id, 'L123');
      expect(back.pickupAt.toIso8601String(), '2025-01-02T03:04:05.000Z');
    });
  });
}
