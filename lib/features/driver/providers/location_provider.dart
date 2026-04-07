import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/offline_storage_provider.dart';

/// Real-time location tracking for drivers
final locationTrackingProvider = StreamProvider<Position>((ref) async* {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions permanently denied');
  }

  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    ),
  );
});

/// Service to upload location or queue when offline
final locationUploadProvider = Provider((ref) => _LocationUploadService(ref));

class _LocationUploadService {
  final Ref ref;
  _LocationUploadService(this.ref);

  Future<void> upload(Position position) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('driver_locations').insert({
        'driver_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': (position.timestamp ?? DateTime.now()).toIso8601String(),
      });
    } catch (_) {
      await ref.read(offlineStorageProvider).queueForSync({
        'type': 'update_location',
        'data': {
          'driver_id': userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': (position.timestamp ?? DateTime.now()).toIso8601String(),
        },
      });
    }
  }
}
