import 'package:flutter/material.dart';
import 'fleet_repository.dart';

/// Minimal real implementation placeholder.
/// In production, this should call your backend APIs.
class BasicFleetRepository implements FleetRepository {
  @override
  Future<FleetKpis> getKpis({required DateTimeRange range}) async {
    // Return zeros to avoid crashes in non-mock mode until real API is wired.
    return const FleetKpis(activeVehicles: 0, jobsToday: 0, delays: 0, alerts: 0);
  }

  @override
  Future<List<AttentionItem>> getNeedsAttention() async {
    return const <AttentionItem>[];
  }
}
