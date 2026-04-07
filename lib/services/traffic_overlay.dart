// lib/services/traffic_overlay.dart
// Helper for calling a PostgREST RPC with proper named params

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> sendTrafficOverlayHeartbeat({String overlay = 'mapbox_traffic'}) async {
  await Supabase.instance.client.rpc(
    'traffic_overlay_heartbeat',
    params: {'p_overlay': overlay},
  );
}
