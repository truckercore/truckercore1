import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/loads/free_caps.dart';

void main() {
  group('FreeLoadCaps.canCreateNew', () {
    test('Free user can create up to 20 active loads (19 -> allowed)', () {
      expect(FreeLoadCaps.canCreateNew(activeCount: 19, isPremium: false), isTrue);
    });
    test('Free user blocked at 20 active loads', () {
      expect(FreeLoadCaps.canCreateNew(activeCount: 20, isPremium: false), isFalse);
    });
    test('Free user blocked beyond 20 (21)', () {
      expect(FreeLoadCaps.canCreateNew(activeCount: 21, isPremium: false), isFalse);
    });
    test('Premium user not capped', () {
      expect(FreeLoadCaps.canCreateNew(activeCount: 1000, isPremium: true), isTrue);
    });
  });
}
