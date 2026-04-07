import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dashboard_analytics.dart';
import '../storage/dashboard_storage.dart';

class DashboardUserState {
  final Set<String> favorites;
  final List<String> recents; // most recent first, unique
  final Map<String, List<String>> collections; // name -> dashboardIds

  const DashboardUserState({
    this.favorites = const {},
    this.recents = const [],
    this.collections = const {},
  });

  DashboardUserState copyWith({
    Set<String>? favorites,
    List<String>? recents,
    Map<String, List<String>>? collections,
  }) {
    return DashboardUserState(
      favorites: favorites ?? this.favorites,
      recents: recents ?? this.recents,
      collections: collections ?? this.collections,
    );
  }
}

class DashboardUserStateNotifier extends StateNotifier<DashboardUserState> {
  DashboardUserStateNotifier(this._storage) : super(const DashboardUserState()) {
    _load();
  }

  final dynamic _storage; // DashboardStorage-like interface
  static const _kFav = 'dashboard_favorites';
  static const _kRec = 'dashboard_recents';
  static const _kCol = 'dashboard_collections';

  Future<void> _load() async {
    try {
      final favs = await _storage.getStringList(_kFav) ?? <String>[];
      final rec = await _storage.getStringList(_kRec) ?? <String>[];
      final colRaw = await _storage.getString(_kCol);
      final Map<String, List<String>> cols;
      if (colRaw != null && colRaw.isNotEmpty) {
        final map = jsonDecode(colRaw) as Map<String, dynamic>;
        cols = map.map((k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()));
      } else {
        cols = <String, List<String>>{};
      }
      state = DashboardUserState(
        favorites: favs.toSet(),
        recents: rec,
        collections: cols,
      );
    } catch (e) {
      debugPrint('DashboardUserState load failed: $e');
    }
  }

  Future<void> _save() async {
    try {
      await _storage.setStringList(_kFav, state.favorites.toList());
      await _storage.setStringList(_kRec, state.recents);
      await _storage.setString(_kCol, jsonEncode(state.collections));
    } catch (e) {
      debugPrint('DashboardUserState save failed: $e');
    }
  }

  bool isFavorite(String id) => state.favorites.contains(id);

  Future<void> toggleFavorite(String id) async {
    final favs = state.favorites.toSet();
    if (favs.contains(id)) {
      favs.remove(id);
    } else {
      favs.add(id);
    }
    state = state.copyWith(favorites: favs);
    await _save();
  }

  Future<void> addRecent(String id) async {
    final list = List<String>.from(state.recents);
    list.remove(id);
    list.insert(0, id);
    while (list.length > 10) {
      list.removeLast();
    }
    state = state.copyWith(recents: list);
    await _save();
  }

  List<String> getRecents() => state.recents;

  Map<String, List<String>> getCollections() => state.collections;

  Future<void> upsertCollection(String name, List<String> dashboardIds) async {
    final cols = Map<String, List<String>>.from(state.collections);
    cols[name] = dashboardIds.toSet().toList();
    state = state.copyWith(collections: cols);
    await _save();
    // Track category create/update (treat update as create for analytics simplicity)
    try {
      await DashboardAnalytics.trackCategoryCreated(name);
    } catch (_) {}
  }

  Future<void> deleteCollection(String name) async {
    final cols = Map<String, List<String>>.from(state.collections);
    cols.remove(name);
    state = state.copyWith(collections: cols);
    await _save();
    try {
      await DashboardAnalytics.trackCategoryDeleted(name);
    } catch (_) {}
  }
}


final dashboardUserStateProvider = StateNotifierProvider<DashboardUserStateNotifier, DashboardUserState>((ref) {
  return DashboardUserStateNotifier(ref.read(dashboardStorageProvider));
});
