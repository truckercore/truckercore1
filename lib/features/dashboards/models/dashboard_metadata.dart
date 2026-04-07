import 'package:flutter/material.dart';
import '../../../common/models/app_role.dart';

class DashboardMetadata {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;
  final Size defaultSize;
  final String category;
  final bool isPremium;
  final List<AppRole> allowedRoles; // empty = allow all

  const DashboardMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
    required this.defaultSize,
    this.category = 'General',
    this.isPremium = false,
    this.allowedRoles = const <AppRole>[],
  });
}

// Available dashboards registry
const List<DashboardMetadata> availableDashboards = [
  DashboardMetadata(
    id: 'fleet_overview',
    name: 'Fleet Overview',
    description: 'Real-time view of all vehicles with status indicators and quick stats',
    icon: Icons.dashboard,
    color: Color(0xFF4CAF50),
    features: [
      'Live vehicle status',
      'Active/Idle/Offline counts',
      'Quick vehicle search',
      'Auto-refresh every 30s',
    ],
    defaultSize: Size(1600, 900),
    category: 'Fleet Management',
    allowedRoles: [AppRole.fleetManager, AppRole.ownerOperator],
  ),
  DashboardMetadata(
    id: 'live_tracking',
    name: 'Live Tracking',
    description: 'Full-screen map with real-time vehicle positions and tracking',
    icon: Icons.map,
    color: Color(0xFF2196F3),
    features: [
      'Interactive map view',
      'Vehicle markers with status',
      'Click to center on vehicle',
      'Real-time position updates',
    ],
    defaultSize: Size(1920, 1080),
    category: 'Fleet Management',
    allowedRoles: [AppRole.fleetManager, AppRole.ownerOperator],
  ),
  DashboardMetadata(
    id: 'load_board',
    name: 'Load Board',
    description: 'DAT load board integration with smart matching and quick dispatch',
    icon: Icons.local_shipping,
    color: Color(0xFFFF9800),
    features: [
      'Live DAT loads',
      'Smart load matching',
      'Rate analysis',
      'One-click dispatch',
    ],
    defaultSize: Size(1400, 800),
    category: 'Load Management',
    isPremium: true,
    allowedRoles: [AppRole.broker],
  ),
  DashboardMetadata(
    id: 'driver_performance',
    name: 'Driver Performance',
    description: 'Driver metrics, safety scores, and performance leaderboards',
    icon: Icons.person,
    color: Color(0xFF9C27B0),
    features: [
      'Safety scores',
      'Fuel efficiency',
      'On-time delivery %',
      'Monthly leaderboard',
    ],
    defaultSize: Size(1400, 900),
    category: 'Analytics',
    allowedRoles: [AppRole.fleetManager, AppRole.ownerOperator],
  ),
  DashboardMetadata(
    id: 'fuel_maintenance',
    name: 'Fuel & Maintenance',
    description: 'Track fuel costs, MPG trends, and maintenance schedules',
    icon: Icons.build,
    color: Color(0xFFF44336),
    features: [
      'Fuel cost tracking',
      'MPG trends',
      'Maintenance alerts',
      'Vendor spend analysis',
    ],
    defaultSize: Size(1400, 900),
    category: 'Operations',
    allowedRoles: [AppRole.fleetManager, AppRole.ownerOperator],
  ),
];
