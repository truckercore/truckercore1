import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FleetKpis {
  final int activeVehicles;
  final int jobsToday;
  final int delays;
  final int alerts;

  const FleetKpis({
    required this.activeVehicles,
    required this.jobsToday,
    required this.delays,
    required this.alerts,
  });
}

class AttentionItem {
  final String id;
  final String title;
  final String subtitle;
  final String severity; // 'low' | 'med' | 'high'

  const AttentionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.severity,
  });
}

abstract class FleetRepository {
  Future<FleetKpis> getKpis({required DateTimeRange range});
  Future<List<AttentionItem>> getNeedsAttention();
}

final fleetRepositoryProvider = Provider<FleetRepository>((ref) {
  throw UnimplementedError('Provide a concrete FleetRepository');
});
