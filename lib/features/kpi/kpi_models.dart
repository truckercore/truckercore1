import 'package:flutter/material.dart';

@immutable
class KpiSnapshot {
  final int openLoads;
  final int fillRatePct; // 0-100
  final double avgRatePerMile; // e.g., 2.41 means $2.41/mi
  final int timeToAssignMedianMin;
  final int activeApprovedCarriers;
  final int docsPending;

  const KpiSnapshot({
    required this.openLoads,
    required this.fillRatePct,
    required this.avgRatePerMile,
    required this.timeToAssignMedianMin,
    required this.activeApprovedCarriers,
    required this.docsPending,
  });

  static const empty = KpiSnapshot(
    openLoads: 0,
    fillRatePct: 0,
    avgRatePerMile: 0,
    timeToAssignMedianMin: 0,
    activeApprovedCarriers: 0,
    docsPending: 0,
  );
}

class KpiFilters {
  final DateTimeRange? range; // default last 7 days if null
  final String? lane; // lane id/name
  final String? equipment;

  const KpiFilters({this.range, this.lane, this.equipment});
}
