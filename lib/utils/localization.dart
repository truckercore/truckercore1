import 'package:intl/intl.dart';

String formatMoney(double value, String currency) =>
  NumberFormat.simpleCurrency(name: currency).format(value);

String formatDistance(double miles, {required bool metric}) =>
  metric ? '${(miles * 1.609344).toStringAsFixed(1)} km' : '${miles.toStringAsFixed(1)} mi';

String formatWeight(double pounds, {required bool metric}) =>
  metric ? '${(pounds * 0.45359237).toStringAsFixed(0)} kg' : '${pounds.toStringAsFixed(0)} lb';

String formatTime(DateTime utc, {String? tzLabel}) {
  final local = utc.toLocal();
  final fmt = DateFormat.jm(); // locale-aware 12/24h
  return tzLabel == null ? fmt.format(local) : '${fmt.format(local)} $tzLabel';
}
