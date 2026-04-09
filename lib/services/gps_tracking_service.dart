import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GpsTrackingService {
  static final GpsTrackingService _instance = GpsTrackingService._internal();
  factory GpsTrackingService() => _instance;
  GpsTrackingService._internal();

  StreamSubscription<Position>? _subscription;
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  Future<void> startTracking({String? orgId}) async {
    if (_isTracking) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services disabled');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    _isTracking = true;

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 25,
      ),
    ).listen((position) async {
      try {
        await supabase.from('gps_locations').insert({
          'user_id': user.id,
          'org_id': orgId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed_mph': position.speed * 2.23694,
          'heading': position.heading,
          'accuracy_meters': position.accuracy,
          'recorded_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        print('GPS insert error: $e');
      }
    });
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    _isTracking = false;
  }
}