import 'package:flutter/material.dart';

class DashboardPreferences {
  final String dashboardId;
  final int refreshIntervalSeconds;
  final bool autoRefresh;
  final bool alwaysOnTop;
  final bool showNotifications;
  final Offset? savedPosition;
  final Size? savedSize;
  final Map<String, dynamic> customSettings;

  const DashboardPreferences({
    required this.dashboardId,
    this.refreshIntervalSeconds = 30,
    this.autoRefresh = true,
    this.alwaysOnTop = false,
    this.showNotifications = true,
    this.savedPosition,
    this.savedSize,
    this.customSettings = const {},
  });

  DashboardPreferences copyWith({
    int? refreshIntervalSeconds,
    bool? autoRefresh,
    bool? alwaysOnTop,
    bool? showNotifications,
    Offset? savedPosition,
    Size? savedSize,
    Map<String, dynamic>? customSettings,
  }) {
    return DashboardPreferences(
      dashboardId: dashboardId,
      refreshIntervalSeconds: refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      showNotifications: showNotifications ?? this.showNotifications,
      savedPosition: savedPosition ?? this.savedPosition,
      savedSize: savedSize ?? this.savedSize,
      customSettings: customSettings ?? this.customSettings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dashboardId': dashboardId,
      'refreshIntervalSeconds': refreshIntervalSeconds,
      'autoRefresh': autoRefresh,
      'alwaysOnTop': alwaysOnTop,
      'showNotifications': showNotifications,
      'savedPosition': savedPosition != null
          ? {'dx': savedPosition!.dx, 'dy': savedPosition!.dy}
          : null,
      'savedSize': savedSize != null
          ? {'width': savedSize!.width, 'height': savedSize!.height}
          : null,
      'customSettings': customSettings,
    };
  }

  factory DashboardPreferences.fromJson(Map<String, dynamic> json) {
    return DashboardPreferences(
      dashboardId: json['dashboardId'] as String,
      refreshIntervalSeconds: json['refreshIntervalSeconds'] as int? ?? 30,
      autoRefresh: json['autoRefresh'] as bool? ?? true,
      alwaysOnTop: json['alwaysOnTop'] as bool? ?? false,
      showNotifications: json['showNotifications'] as bool? ?? true,
      savedPosition: json['savedPosition'] != null
          ? Offset(
              (json['savedPosition']['dx'] as num).toDouble(),
              (json['savedPosition']['dy'] as num).toDouble(),
            )
          : null,
      savedSize: json['savedSize'] != null
          ? Size(
              (json['savedSize']['width'] as num).toDouble(),
              (json['savedSize']['height'] as num).toDouble(),
            )
          : null,
      customSettings: (json['customSettings'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}
