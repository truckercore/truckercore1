// Helper to build a redacted CSV for compare/share
String buildCompareCsv(List<Map<String, dynamic>> rows) {
  final headers = ['Load', 'Lane', 'Distance', 'CPM', 'ETA', 'Trust'];
  final lines = <String>[];
  lines.add(headers.join(','));
  for (final r in rows) {
    lines.add([
      r['reference'] ?? '',
      r['lane'] ?? '',
      r['distance'] ?? '',
      r['cpm'] ?? '',
      r['eta'] ?? '',
      r['trust'] ?? ''
    ].join(','));
  }
  return lines.join('\n');
}
