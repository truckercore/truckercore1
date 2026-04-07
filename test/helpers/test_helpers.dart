import 'package:flutter/material.dart';

Widget dashboardEntryForTest(Map<String, dynamic> args) {
  final id = (args['dashboardId'] ?? '').toString();
  return MaterialApp(
    home: Scaffold(
      body: Center(child: Text('Unknown Dashboard: $id')),
    ),
  );
}

double clusterSizeForCount(int count) {
  if (count <= 10) return 40.0;
  if (count <= 50) return 50.0;
  if (count <= 100) return 60.0;
  return 70.0;
}

IconData vehicleIconForStatus(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return Icons.local_shipping;
    case 'idle':
      return Icons.pause_circle;
    case 'maintenance':
      return Icons.build;
    default:
      return Icons.local_shipping;
  }
}

bool isOnlineFromResults(dynamic results) {
  if (results is Map) {
    return results['online'] == true || results['isOnline'] == true;
  }
  return false;
}
