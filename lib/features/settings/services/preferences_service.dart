import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/supa_client.dart';
import '../models/user_preferences.dart';

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

final userPreferencesProvider = FutureProvider<UserPreferences>((ref) async {
  final service = ref.watch(preferencesServiceProvider);
  return service.getPreferences();
});

class PreferencesService {
  static const String _prefsKey = 'user_preferences';

  /// Get user preferences (local first, then sync with server)
  Future<UserPreferences> getPreferences() async {
    // Try local storage first
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString(_prefsKey);

    if (localJson != null) {
      try {
        return UserPreferences.fromJson(
          Map<String, dynamic>.from(jsonDecode(localJson) as Map),
        );
      } catch (_) {
        // If local data is corrupted, fetch from server
      }
    }

    // Fetch from server
    try {
      final response = await SupaClient.from('user_preferences')
          .select('preferences')
          .single();

      final map = Map<String, dynamic>.from(response as Map);
      final serverPrefs = UserPreferences.fromJson(
        Map<String, dynamic>.from(map['preferences'] as Map),
      );

      // Cache locally
      await _saveLocal(serverPrefs);
      return serverPrefs;
    } catch (_) {
      // Return defaults if both local and server fail
      return const UserPreferences();
    }
  }

  /// Update preferences
  Future<void> updatePreferences(UserPreferences preferences) async {
    // Save to server
    await SupaClient.from('user_preferences').upsert({
      'preferences': preferences.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Save locally
    await _saveLocal(preferences);
  }

  /// Save preferences locally
  Future<void> _saveLocal(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(preferences.toJson()));
  }

  /// Clear all preferences
  Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);

    await SupaClient.from('user_preferences').delete();
  }
}
