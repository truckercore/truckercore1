// lib/map/pages/map_cluster_demo.dart
// A lightweight demo page to showcase ClusterMap without altering app navigation.

import 'package:flutter/material.dart';
import '../widgets/cluster_map.dart';

class MapClusterDemoPage extends StatelessWidget {
  final double lat;
  final double lng;
  final Future<String?> Function()? getAuthToken;

  const MapClusterDemoPage({super.key, required this.lat, required this.lng, this.getAuthToken});

  static Widget builder({required double lat, required double lng, Future<String?> Function()? getAuthToken}) =>
      MapClusterDemoPage(lat: lat, lng: lng, getAuthToken: getAuthToken);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clustered Map Demo')),
      body: ClusterMap(
        initialLat: lat,
        initialLng: lng,
        getAuthToken: getAuthToken,
      ),
    );
  }
}
