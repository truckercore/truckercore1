class KpiFormat {
  KpiFormat._();

  static String moneyPerMile(double v) {
    if (v <= 0) return '—/mi';
    return '\$${v.toStringAsFixed(2)}/mi';
  }

  static String percent(int v) => '${v.clamp(0, 100)}%';

  static String minutes(int m) => m <= 0 ? '—' : '${m}m';
}
