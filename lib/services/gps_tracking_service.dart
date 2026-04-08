import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GpsTrackingService {
  GpsTrackingService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  StreamSubscription<Position>? _subscription;

  Future<void> start() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User must be signed in before GPS tracking starts.');
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission not granted.');
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 25,
    );

    await _subscription?.cancel();

    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      await _writeLocation(position, user.id);
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _writeLocation(Position position, String userId) async {
    await _supabase.from('gps_locations').insert({
      'user_id': userId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'heading': position.heading,
      'speed_mph': position.speed * 2.23694,
      'accuracy_meters': position.accuracy,
      'recorded_at': position.timestamp?.toUtc().toIso8601String(),
    });
  }
}