// lib/common/config/app_config.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  final String backend;
  final String mapboxToken;
  final String trimbleBaseUrl;
  final bool useMockData;
  final String supabaseUrl;
  final String supabaseAnonKey;
  // thresholds
  final int idleMinutes;
  final int offlineMinutes;
  final double speedIdleKph;

  const AppConfig({
    required this.backend,
    required this.mapboxToken,
    required this.trimbleBaseUrl,
    required this.useMockData,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.idleMinutes = 10,
    this.offlineMinutes = 30,
    this.speedIdleKph = 3.0,
  });
}

const appConfigFromEnv = AppConfig(
  backend: String.fromEnvironment('BACKEND', defaultValue: 'firebase'),
  mapboxToken: String.fromEnvironment('MAPBOX_TOKEN'),
  trimbleBaseUrl: String.fromEnvironment(
    'TRIMBLE_BASE_URL',
    defaultValue: 'http://localhost:8080',
  ),
  useMockData: bool.fromEnvironment('USE_MOCK_DATA', defaultValue: true),
  supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
  // Prefer SUPABASE_ANON; fall back to legacy SUPABASE_ANON_KEY
  supabaseAnonKey: (String.fromEnvironment('SUPABASE_ANON') != '')
      ? String.fromEnvironment('SUPABASE_ANON')
      : String.fromEnvironment('SUPABASE_ANON_KEY'),
);

final appConfigProvider = Provider<AppConfig>((ref) => appConfigFromEnv);
