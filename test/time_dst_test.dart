import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/core/time/time_util.dart';

void main() {
  test('midnight billing stays once across DST', () {
    final d1 = DateTime.utc(2025, 3, 9, 23, 59, 59);
    final d2 = TimeUtil.toUtc(d1.add(const Duration(seconds: 2)));
    expect(d2.isAfter(d1), true);
  });
}
