// lib/common/formatting/formatting.dart
import 'package:intl/intl.dart';

String formatMoney(num? value, {String currency = ''}) {
  // Use $ by default; allow callers to override
  final v = (value ?? 0).toDouble();
  final f = NumberFormat.currency(symbol: currency == '' ? r'$' : currency, decimalDigits: v == v.roundToDouble() ? 0 : 2);
  return f.format(v);
}

String formatCpm(num? dollarsPerMile) {
  if (dollarsPerMile == null) return '-';
  final v = dollarsPerMile.toDouble();
  return '\$${v.toStringAsFixed(2)}/mi';
}

String formatCph(num? dollarsPerHour) {
  if (dollarsPerHour == null) return '-';
  final v = dollarsPerHour.toDouble();
  return '\$${v.toStringAsFixed(0)}/h';
}

String formatMiles(num? miles) {
  if (miles == null) return '-';
  final m = miles.toDouble();
  return '${m.toStringAsFixed(m < 100 ? 1 : 0)} mi';
}

String shortDate(DateTime dt) {
  final f = DateFormat('MMM d');
  return f.format(dt.toLocal());
}
