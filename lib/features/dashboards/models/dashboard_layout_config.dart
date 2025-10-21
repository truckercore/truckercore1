import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DashboardLayoutConfig {
  final List<String> visibleMetrics; // e.g., ['performance','safety','fuel','ontime']
  final String sortBy; // same options as above
  final bool showInactive;

  const DashboardLayoutConfig({
    this.visibleMetrics = const ['performance', 'safety', 'fuel', 'ontime'],
    this.sortBy = 'performance',
    this.showInactive = true,
  });

  DashboardLayoutConfig copyWith({
    List<String>? visibleMetrics,
    String? sortBy,
    bool? showInactive,
  }) {
    return DashboardLayoutConfig(
      visibleMetrics: visibleMetrics ?? this.visibleMetrics,
      sortBy: sortBy ?? this.sortBy,
      showInactive: showInactive ?? this.showInactive,
    );
  }

  Map<String, dynamic> toJson() => {
        'visibleMetrics': visibleMetrics,
        'sortBy': sortBy,
        'showInactive': showInactive,
      };

  factory DashboardLayoutConfig.fromJson(Map<String, dynamic> json) {
    return DashboardLayoutConfig(
      visibleMetrics: (json['visibleMetrics'] as List?)?.map((e) => e.toString()).toList() ??
          const ['performance', 'safety', 'fuel', 'ontime'],
      sortBy: (json['sortBy'] as String?) ?? 'performance',
      showInactive: (json['showInactive'] as bool?) ?? true,
    );
  }

  static Future<DashboardLayoutConfig> load(String dashboardId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('layout_$dashboardId');
    if (raw == null || raw.isEmpty) return const DashboardLayoutConfig();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DashboardLayoutConfig.fromJson(map);
    } catch (_) {
      return const DashboardLayoutConfig();
    }
  }

  Future<void> save(String dashboardId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('layout_$dashboardId', jsonEncode(toJson()));
  }
}
