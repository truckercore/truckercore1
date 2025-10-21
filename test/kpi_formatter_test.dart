import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/kpi/kpi_repository.dart';

void main() {
  group('KpiFormatter', () {
    test('moneyPerMile formats correctly', () {
      expect(KpiFormatter.moneyPerMile(2.4), r'$2.40/mi');
      expect(KpiFormatter.moneyPerMile(0), '\u0000/mi');
    });
    test('percent clamps and formats', () {
      expect(KpiFormatter.percent(92), '92%');
      expect(KpiFormatter.percent(150), '100%');
    });
    test('minutes formats', () {
      expect(KpiFormatter.minutes(28), '28m');
      expect(KpiFormatter.minutes(0), '—');
    });
  });
}
