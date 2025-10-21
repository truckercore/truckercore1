// lib/shared/formatters.dart
import 'package:intl/intl.dart';

String dateFmt(DateTime dt) => DateFormat('MMM d, h:mm a').format(dt.toLocal());
String moneyFmt(num v, {String? currencyCode}) => NumberFormat.simpleCurrency(name: currencyCode).format(v);
String miles(num v) => '${v.toStringAsFixed(0)} mi';
