import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/models/app_role.dart';
import '../../features/dashboards/models/dashboard_metadata.dart';

/// Simple RBAC service used across Flutter app to centralize permission checks.
class RbacService {
  const RbacService();

  bool hasRole(AppRole current, AppRole role) => current == role;

  bool hasAnyRole(AppRole current, List<AppRole> roles) {
    if (roles.isEmpty) return true; // empty = allow all
    return roles.contains(current);
  }

  /// Returns true if the user role is allowed to view the given dashboard.
  bool canViewDashboard({required AppRole current, required DashboardMetadata dashboard}) {
    return hasAnyRole(current, dashboard.allowedRoles);
  }
}

final rbacProvider = Provider<RbacService>((ref) => const RbacService());
