class UserPreferences {
  final bool notificationsEnabled;
  final bool hosAlertsEnabled;
  final bool safetyAlertsEnabled;
  final bool maintenanceAlertsEnabled;
  final bool loadNotificationsEnabled;
  final String distanceUnit; // 'miles' or 'km'
  final String temperatureUnit; // 'fahrenheit' or 'celsius'
  final String mapStyle; // 'standard', 'satellite', 'hybrid'
  final bool offlineMode;
  final bool autoDownloadMaps;
  final int mapUpdateFrequency; // in hours
  final bool voiceNavigationEnabled;
  final String language;
  final String theme; // 'light', 'dark', 'auto'

  const UserPreferences({
    this.notificationsEnabled = true,
    this.hosAlertsEnabled = true,
    this.safetyAlertsEnabled = true,
    this.maintenanceAlertsEnabled = true,
    this.loadNotificationsEnabled = true,
    this.distanceUnit = 'miles',
    this.temperatureUnit = 'fahrenheit',
    this.mapStyle = 'standard',
    this.offlineMode = false,
    this.autoDownloadMaps = false,
    this.mapUpdateFrequency = 24,
    this.voiceNavigationEnabled = true,
    this.language = 'en',
    this.theme = 'dark',
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        hosAlertsEnabled: json['hos_alerts_enabled'] as bool? ?? true,
        safetyAlertsEnabled: json['safety_alerts_enabled'] as bool? ?? true,
        maintenanceAlertsEnabled: json['maintenance_alerts_enabled'] as bool? ?? true,
        loadNotificationsEnabled: json['load_notifications_enabled'] as bool? ?? true,
        distanceUnit: json['distance_unit'] as String? ?? 'miles',
        temperatureUnit: json['temperature_unit'] as String? ?? 'fahrenheit',
        mapStyle: json['map_style'] as String? ?? 'standard',
        offlineMode: json['offline_mode'] as bool? ?? false,
        autoDownloadMaps: json['auto_download_maps'] as bool? ?? false,
        mapUpdateFrequency: json['map_update_frequency'] as int? ?? 24,
        voiceNavigationEnabled: json['voice_navigation_enabled'] as bool? ?? true,
        language: json['language'] as String? ?? 'en',
        theme: json['theme'] as String? ?? 'dark',
      );

  Map<String, dynamic> toJson() => {
        'notifications_enabled': notificationsEnabled,
        'hos_alerts_enabled': hosAlertsEnabled,
        'safety_alerts_enabled': safetyAlertsEnabled,
        'maintenance_alerts_enabled': maintenanceAlertsEnabled,
        'load_notifications_enabled': loadNotificationsEnabled,
        'distance_unit': distanceUnit,
        'temperature_unit': temperatureUnit,
        'map_style': mapStyle,
        'offline_mode': offlineMode,
        'auto_download_maps': autoDownloadMaps,
        'map_update_frequency': mapUpdateFrequency,
        'voice_navigation_enabled': voiceNavigationEnabled,
        'language': language,
        'theme': theme,
      };

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? hosAlertsEnabled,
    bool? safetyAlertsEnabled,
    bool? maintenanceAlertsEnabled,
    bool? loadNotificationsEnabled,
    String? distanceUnit,
    String? temperatureUnit,
    String? mapStyle,
    bool? offlineMode,
    bool? autoDownloadMaps,
    int? mapUpdateFrequency,
    bool? voiceNavigationEnabled,
    String? language,
    String? theme,
  }) {
    return UserPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      hosAlertsEnabled: hosAlertsEnabled ?? this.hosAlertsEnabled,
      safetyAlertsEnabled: safetyAlertsEnabled ?? this.safetyAlertsEnabled,
      maintenanceAlertsEnabled: maintenanceAlertsEnabled ?? this.maintenanceAlertsEnabled,
      loadNotificationsEnabled: loadNotificationsEnabled ?? this.loadNotificationsEnabled,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      mapStyle: mapStyle ?? this.mapStyle,
      offlineMode: offlineMode ?? this.offlineMode,
      autoDownloadMaps: autoDownloadMaps ?? this.autoDownloadMaps,
      mapUpdateFrequency: mapUpdateFrequency ?? this.mapUpdateFrequency,
      voiceNavigationEnabled: voiceNavigationEnabled ?? this.voiceNavigationEnabled,
      language: language ?? this.language,
      theme: theme ?? this.theme,
    );
  }
}
