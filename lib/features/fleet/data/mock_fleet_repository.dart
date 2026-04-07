import 'dart:math';
import 'package:flutter/material.dart';
import 'fleet_repository.dart';

class MockFleetRepository implements FleetRepository {
  final _rng = Random();

  @override
  Future<FleetKpis> getKpis({required DateTimeRange range}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return FleetKpis(
      activeVehicles: 42 + _rng.nextInt(5),
      jobsToday: 120 + _rng.nextInt(15),
      delays: 3 + _rng.nextInt(4),
      alerts: 1 + _rng.nextInt(3),
    );
  }

  @override
  Future<List<AttentionItem>> getNeedsAttention() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const [
      AttentionItem(
        id: 'maint-001',
        title: 'Maintenance due',
        subtitle: 'Vehicle #TC-104 — 600 mi over',
        severity: 'high',
      ),
      AttentionItem(
        id: 'route-021',
        title: 'Out of route',
        subtitle: 'Vehicle #TC-233 — 3.5 mi off planned path',
        severity: 'med',
      ),
      AttentionItem(
        id: 'fuel-090',
        title: 'Low fuel',
        subtitle: 'Vehicle #TC-118 — 8%',
        severity: 'low',
      ),
    ];
  }
}
