// lib/core/format/formatters.dart
import 'package:intl/intl.dart';

String dateShort(DateTime dt) {
  final local = dt.toLocal();
  return DateFormat('MMM d, h:mm a').format(local);
}

String money(num v, {String? currencyCode}) {
  final f = NumberFormat.simpleCurrency(name: currencyCode);
  return f.format(v);
}

String miles(num v) => '${v.toStringAsFixed(0)} mi';
