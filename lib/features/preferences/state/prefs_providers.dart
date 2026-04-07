// lib/features/preferences/state/prefs_providers.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  final String? defaultEquipment;
  final double? minCpm; // dollars per mile
  final double? homeBaseLat;
  final double? homeBaseLng;
  final double? homeRadiusMi;
  final List<String> preferredLanes; // e.g., ["OR-CA", "PA-NJ"]
  final List<String> dislikedBrokers; // broker ids or names
  final String? pickupWindowStartIso; // ISO8601
  final String? pickupWindowEndIso; // ISO8601

  const UserPrefs({
    this.defaultEquipment,
    this.minCpm,
    this.homeBaseLat,
    this.homeBaseLng,
    this.homeRadiusMi,
    this.preferredLanes = const [],
    this.dislikedBrokers = const [],
    this.pickupWindowStartIso,
    this.pickupWindowEndIso,
  });

  Map<String, dynamic> toJson() => {
        'defaultEquipment': defaultEquipment,
        'minCpm': minCpm,
        'homeBaseLat': homeBaseLat,
        'homeBaseLng': homeBaseLng,
        'homeRadiusMi': homeRadiusMi,
        'preferredLanes': preferredLanes,
        'dislikedBrokers': dislikedBrokers,
        'pickupWindowStartIso': pickupWindowStartIso,
        'pickupWindowEndIso': pickupWindowEndIso,
      };

  factory UserPrefs.fromJson(Map<String, dynamic> j) => UserPrefs(
        defaultEquipment: j['defaultEquipment'] as String?,
        minCpm: (j['minCpm'] as num?)?.toDouble(),
        homeBaseLat: (j['homeBaseLat'] as num?)?.toDouble(),
        homeBaseLng: (j['homeBaseLng'] as num?)?.toDouble(),
        homeRadiusMi: (j['homeRadiusMi'] as num?)?.toDouble(),
        preferredLanes: (j['preferredLanes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        dislikedBrokers: (j['dislikedBrokers'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        pickupWindowStartIso: j['pickupWindowStartIso'] as String?,
        pickupWindowEndIso: j['pickupWindowEndIso'] as String?,
      );
}

class UserPrefsController extends AsyncNotifier<UserPrefs> {
  static const _key = 'user_prefs_v1';

  @override
  Future<UserPrefs> build() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null) return const UserPrefs();
    try {
      return UserPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const UserPrefs();
    }
  }

  Future<void> save(UserPrefs prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(prefs.toJson()));
    state = AsyncData(prefs);
  }
}

final userPrefsProvider = AsyncNotifierProvider<UserPrefsController, UserPrefs>(() => UserPrefsController());

/// Small banner toggle provider to show that personalization is active.
final personalizationBannerProvider = StateProvider<bool>((ref) => true);
