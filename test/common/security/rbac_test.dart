import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/common/models/app_role.dart';
import 'package:truckercore1/common/security/rbac.dart';
import 'package:truckercore1/features/dashboards/models/dashboard_metadata.dart';

void main() {
  group('RbacService', () {
    final rbac = const RbacService();

    DashboardMetadata dash(List<AppRole> roles) => DashboardMetadata(
      id: 'd1',
      name: 'Test',
      description: 'desc',
      icon: Icons.dashboard,
      color: Colors.blue,
      features: const [],
      defaultSize: const Size(100, 100),
      allowedRoles: roles,
    );

    test('allows all when allowedRoles is empty', () {
      expect(rbac.canViewDashboard(current: AppRole.driver, dashboard: dash(const [])), true);
      expect(rbac.canViewDashboard(current: AppRole.broker, dashboard: dash(const [])), true);
    });

    test('denies when role not in allowed list', () {
      final d = dash(const [AppRole.fleetManager, AppRole.ownerOperator]);
      expect(rbac.canViewDashboard(current: AppRole.driver, dashboard: d), false);
      expect(rbac.canViewDashboard(current: AppRole.broker, dashboard: d), false);
    });

    test('allows when role is in allowed list', () {
      final d = dash(const [AppRole.driver, AppRole.ownerOperator]);
      expect(rbac.canViewDashboard(current: AppRole.driver, dashboard: d), true);
      expect(rbac.canViewDashboard(current: AppRole.ownerOperator, dashboard: d), true);
    });
  });
}
