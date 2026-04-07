// Simple coverage gate for Flutter/Dart. Parses lcov.info and enforces a minimum line coverage.
// Usage (CI):
//   flutter test --coverage
//   dart run scripts/coverage_check.dart 0.40
// Exits with non-zero status if coverage is below threshold.

import 'dart:convert';
import 'dart:io';

bool _isExcludedFile(String path) {
  // Exclude generated and platform glue from coverage
  final p = path.replaceAll('\\', '/');
  if (p.contains('/build/')) return true;
  if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) return true;
  if (p.contains('GeneratedPluginRegistrant')) return true;
  if (p.contains('/windows/flutter/generated')) return true;
  if (p.contains('/linux/flutter/generated')) return true;
  if (p.contains('/macos/Flutter/Generated')) return true;
  if (p.contains('/ios/Runner/Generated')) return true;
  if (p.contains(
    '/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
  )) {
    return true;
  }
  if (p.contains('/testcontainers-cloud-java-example/')) return true;
  return false;
}

void main(List<String> args) async {
  final threshold = args.isNotEmpty
      ? double.tryParse(args[0]) ?? 0.4
      : 0.4; // default 40%
  final file = File('coverage/lcov.info');
  if (!await file.exists()) {
    stderr.writeln(
      'coverage/lcov.info not found. Run flutter test --coverage first.',
    );
    exit(2);
  }
  final content = await file.readAsString();
  final lines = LineSplitter.split(content);
  int found = 0;
  int hit = 0;
  String? currentFile;
  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3).trim();
      continue;
    }
    if (line.startsWith('DA:')) {
      if (currentFile != null && _isExcludedFile(currentFile)) continue;
      // DA:<line number>,<execution count>
      final parts = line.substring(3).split(',');
      if (parts.length == 2) {
        found += 1;
        final count = int.tryParse(parts[1]) ?? 0;
        if (count > 0) hit += 1;
      }
    }
  }
  final coverage = found == 0 ? 0.0 : hit / found;
  final pct = (coverage * 100).toStringAsFixed(2);
  stdout.writeln(
    'Coverage (filtered): $pct% (threshold ${(threshold * 100).toStringAsFixed(0)}%)',
  );
  if (coverage + 1e-9 < threshold) {
    stderr.writeln('Coverage below threshold. Failing.');
    exit(1);
  }
}
