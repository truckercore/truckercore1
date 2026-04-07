import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Generate a CSV for a list of vehicle-like objects.
/// Accepts any objects that expose fields: unitNumber, status, speed, driverName.
Future<String> generateCSV(List<dynamic> vehicles) async {
  final buffer = StringBuffer();
  buffer.writeln('Unit,Status,Speed,Driver');
  for (final v in vehicles) {
    try {
      // Dynamic getters; will work for classes with matching fields.
      final unit = (v as dynamic).unitNumber?.toString() ?? '';
      final status = (v as dynamic).status?.toString() ?? '';
      final speedVal = (v as dynamic).speed;
      final speed = speedVal == null ? '0' : (speedVal is num ? speedVal.toString() : '0');
      final driver = (v as dynamic).driverName?.toString() ?? 'N/A';
      buffer.writeln('$unit,$status,$speed,$driver');
    } catch (_) {
      // If object shape is not compatible, skip that row
    }
  }
  return buffer.toString();
}

/// Save content to a file in the user's Downloads directory when available,
/// otherwise fallback to application documents directory. Returns full path.
Future<String> saveToDisk(String baseFileName, String content) async {
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final sanitized = baseFileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  final fileName = '${sanitized}_$timestamp.csv';

  Directory? dir;
  try {
    // Not all platforms implement getDownloadsDirectory; handle gracefully.
    // ignore: deprecated_member_use
    dir = await getDownloadsDirectory();
  } catch (_) {}
  dir ??= await getApplicationDocumentsDirectory();

  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(content);
  return file.path;
}
