import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/kpi/kpi_format.dart';

void main() {
  group('KpiFormat.moneyPerMile', () {
    test(r'formats positive values to $/mi with 2 decimals', () {
      expect(KpiFormat.moneyPerMile(2.4), r'$2.40/mi');
      expect(KpiFormat.moneyPerMile(2.456), r'$2.46/mi');
    });
    test('returns em dash for zero/negative', () {
      expect(KpiFormat.moneyPerMile(0), '—/mi');
      expect(KpiFormat.moneyPerMile(-1), '—/mi');
    });
  });

  group('KpiFormat.percent', () {
    test('clamps to 0..100 and adds %', () {
      expect(KpiFormat.percent(0), '0%');
      expect(KpiFormat.percent(55), '55%');
      expect(KpiFormat.percent(150), '100%');
      expect(KpiFormat.percent(-10), '0%');
    });
  });

  group('KpiFormat.minutes', () {
    test('em dash when <= 0', () {
      expect(KpiFormat.minutes(0), '—');
      expect(KpiFormat.minutes(-5), '—');
    });
    test('formats positive minutes', () {
      expect(KpiFormat.minutes(1), '1m');
      expect(KpiFormat.minutes(28), '28m');
    });
  });
}
