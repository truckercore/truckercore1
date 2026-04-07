import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_role.dart';
import 'session_provider.dart';

class RoleFeatures {
  final bool safetyScore; // self/fleet
  final bool vehicleHealth; // own assets
  final bool fuelLogs; // personal fuel logs
  final bool iftaExport; // ifta export
  final bool hosDotMode; // DOT inspection mode
  final bool exceptionsKpi; // dispatcher KPI strip
  final bool onTimeRate; // KPI for on-time
  final bool unassignedLoads; // show unassigned loads
  final bool deadheadPct; // KPI deadhead
  final bool maintenancePlanner; // planner visibility
  final bool helpTraining; // tutorials

  const RoleFeatures({
    required this.safetyScore,
    required this.vehicleHealth,
    required this.fuelLogs,
    required this.iftaExport,
    required this.hosDotMode,
    required this.exceptionsKpi,
    required this.onTimeRate,
    required this.unassignedLoads,
    required this.deadheadPct,
    required this.maintenancePlanner,
    required this.helpTraining,
  });
}

RoleFeatures _forRole(AppRole role) {
  switch (role) {
    case AppRole.driver:
      return const RoleFeatures(
        safetyScore: true,
        vehicleHealth: true,
        fuelLogs: true,
        iftaExport: false,
        hosDotMode: true,
        exceptionsKpi: false,
        onTimeRate: false,
        unassignedLoads: false,
        deadheadPct: false,
        maintenancePlanner: true,
        helpTraining: true,
      );
    case AppRole.ownerOperator:
      return const RoleFeatures(
        safetyScore: true,
        vehicleHealth: true,
        fuelLogs: true,
        iftaExport: true,
        hosDotMode: true,
        exceptionsKpi: false, // simplified, keep in profitability context
        onTimeRate: true,
        unassignedLoads: false,
        deadheadPct: true,
        maintenancePlanner: true,
        helpTraining: true,
      );
    case AppRole.broker:
      return const RoleFeatures(
        safetyScore: false, // optional; add via local flag
        vehicleHealth: false,
        fuelLogs: false,
        iftaExport: false,
        hosDotMode: true, // can request/verify
        exceptionsKpi: false,
        onTimeRate: true, // for brokered loads
        unassignedLoads: true, // matching
        deadheadPct: false,
        maintenancePlanner: false,
        helpTraining: true,
      );
    case AppRole.fleetManager:
      return const RoleFeatures(
        safetyScore: true,
        vehicleHealth: true,
        fuelLogs: true,
        iftaExport: true,
        hosDotMode: true,
        exceptionsKpi: true,
        onTimeRate: true,
        unassignedLoads: true,
        deadheadPct: true,
        maintenancePlanner: true,
        helpTraining: true,
      );
  }
}

final roleFeaturesProvider = Provider<RoleFeatures>((ref) {
  final session = ref.watch(sessionProvider);
  return _forRole(session.role);
});
