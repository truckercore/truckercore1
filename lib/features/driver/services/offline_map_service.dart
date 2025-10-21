import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/route_result.dart';
import '../../../services/supa_client.dart';
import '../models/offline_region.dart';

final offlineMapServiceProvider = Provider<OfflineMapService>((ref) {
  return OfflineMapService();
});

class OfflineMapService {
  /// Download map region for offline use
  Future<String> downloadMapRegion({
    required String name,
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    int minZoom = 8,
    int maxZoom = 15,
  }) async {
    final response = await SupaClient.functions('download-map-region', {
      'name': name,
      'bounds': {
        'min_lat': minLat,
        'min_lng': minLng,
        'max_lat': maxLat,
        'max_lng': maxLng,
      },
      'min_zoom': minZoom,
      'max_zoom': maxZoom,
    });

    final downloadUrl = response.data['download_url'] as String;
    final regionId = response.data['region_id'] as String;

    // Download map tiles to local storage
    await _downloadAndSaveRegion(regionId, downloadUrl);

    return regionId;
  }

  /// Get list of downloaded offline regions
  Future<List<OfflineRegion>> getDownloadedRegions() async {
    final response = await SupaClient.from('offline_map_regions')
        .select('*')
        .eq('downloaded', true)
        .order('downloaded_at', ascending: false);

    return (response as List).map((r) => OfflineRegion.fromJson(r)).toList();
  }

  /// Delete offline map region
  Future<void> deleteMapRegion(String regionId) async {
    final dir = await getApplicationDocumentsDirectory();
    final regionDir = Directory('${dir.path}/offline_maps/$regionId');

    if (await regionDir.exists()) {
      await regionDir.delete(recursive: true);
    }

    await SupaClient.from('offline_map_regions').delete().eq('id', regionId);
  }

  /// Cache route for offline navigation
  Future<void> cacheRoute({
    required String routeId,
    required List<LatLng> polyline,
    required Map<String, dynamic> routeData,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final routeFile = File('${dir.path}/cached_routes/$routeId.json');

    await routeFile.parent.create(recursive: true);
    await routeFile.writeAsString(jsonEncode({
      'route_id': routeId,
      'polyline': polyline.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
      'route_data': routeData,
      'cached_at': DateTime.now().toIso8601String(),
    }));
  }

  /// Get cached route
  Future<Map<String, dynamic>?> getCachedRoute(String routeId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final routeFile = File('${dir.path}/cached_routes/$routeId.json');

      if (await routeFile.exists()) {
        final content = await routeFile.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Check if region is available offline
  Future<bool> isRegionAvailable({
    required double lat,
    required double lng,
  }) async {
    final regions = await getDownloadedRegions();

    return regions.any((region) =>
        lat >= region.minLat &&
        lat <= region.maxLat &&
        lng >= region.minLng &&
        lng <= region.maxLng);
  }

  /// Get offline map storage size
  Future<int> getStorageSize() async {
    final dir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory('${dir.path}/offline_maps');

    if (!await mapsDir.exists()) {
      return 0;
    }

    int totalSize = 0;
    await for (final entity in mapsDir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  Future<void> _downloadAndSaveRegion(String regionId, String downloadUrl) async {
    // Implementation would download tiles and save to local storage
    // Placeholder for actual download logic
    final dir = await getApplicationDocumentsDirectory();
    final regionDir = Directory('${dir.path}/offline_maps/$regionId');
    await regionDir.create(recursive: true);

    await SupaClient.from('offline_map_regions')
        .update({
          'downloaded': true,
          'downloaded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', regionId);
  }
}
