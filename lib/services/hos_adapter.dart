// lib/services/hos_adapter.dart
// Thin client for calling the database RPC hos_remaining_drive_minutes
// Returns: ({remainingMinutes, adjustedForHos})

import 'package:supabase_flutter/supabase_flutter.dart';

Future<({int remainingMinutes, bool adjustedForHos})> hosRemainingDriveMinutes({
  required String driverUserId,
  DateTime? at,
}) async {
  final sb = Supabase.instance.client;
  final params = <String, dynamic>{
    'p_driver_user_id': driverUserId,
    if (at != null) 'p_at': at.toUtc().toIso8601String(),
  };
  final result = await sb.rpc('hos_remaining_drive_minutes', params: params);
  // Function returns SETOF table so PostgREST yields a List
  final rows = (result as List).cast<Map<String, dynamic>>();
  if (rows.isEmpty) {
    // Defensive default: 0 minutes, adjusted
    return (remainingMinutes: 0, adjustedForHos: true);
  }
  final row = rows.first;
  final minutes = (row['remaining_minutes'] as num?)?.toInt() ?? 0;
  final adjusted = row['adjusted_for_hos'] as bool? ?? (minutes < 120);
  return (remainingMinutes: minutes, adjustedForHos: adjusted);
}
