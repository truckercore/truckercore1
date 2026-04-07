
Map<String, dynamic> buildRoaddoggContext({
  required String shell,
  required String route,
  String? selectedId,
  Map<String, dynamic>? extras,
}) {
  return {
    'shell': shell,
    'route': route,
    if (selectedId != null) 'selectedId': selectedId,
    if (extras != null) ...extras,
  };
}
