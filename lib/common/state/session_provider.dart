import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_role.dart';

class AuthState {
  final bool isLoggedIn;
  const AuthState({required this.isLoggedIn});

  AuthState copyWith({bool? isLoggedIn}) =>
      AuthState(isLoggedIn: isLoggedIn ?? this.isLoggedIn);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState(isLoggedIn: false));

  void logIn() => state = state.copyWith(isLoggedIn: true);
  void logOut() => state = state.copyWith(isLoggedIn: false);
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});

// SessionController manages the selected role and premium flag for the current user.
class SessionController extends StateNotifier<UserSession> {
  SessionController()
    : super(const UserSession(role: AppRole.driver, isPremium: false)) {
    _restorePersistedRole();
  }

  final Completer<void> _restored = Completer<void>();
  Future<void> waitUntilRestored() => _restored.future;

  static const _kRoleKey = 'session.current_role_v1';
  static const _kUserChosenKey = 'session.role_chosen_v1';

  String _scopedKey(String base) {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) return '$base.$uid';
    } catch (_) {}
    return base; // fallback to legacy global key
  }

  Future<void> _restorePersistedRole() async {
    try {
      final sp = await SharedPreferences.getInstance();
      // Prefer user-scoped keys; fall back to legacy global keys
      final roleKey = _scopedKey(_kRoleKey);
      final chosenKey = _scopedKey(_kUserChosenKey);
      String? roleStr = sp.getString(roleKey);
      bool chosen = sp.getBool(chosenKey) ?? false;
      // Legacy fallback (pre-scoped)
      roleStr ??= sp.getString(_kRoleKey);
      if (!chosen) {
        chosen = sp.getBool(_kUserChosenKey) ?? false;
      }
      if (roleStr != null) {
        final r = _roleFromString(roleStr);
        if (r != null) {
          state = UserSession(
            role: r,
            isPremium: state.isPremium,
            userChosenRole: chosen,
          );
        }
      }
    } catch (_) {
    } finally {
      if (!_restored.isCompleted) {
        _restored.complete();
      }
    }
  }

  Future<void> _persistRole(AppRole role, bool userChosen) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final roleKey = _scopedKey(_kRoleKey);
      final chosenKey = _scopedKey(_kUserChosenKey);
      await sp.setString(roleKey, role.name);
      await sp.setBool(chosenKey, userChosen);
    } catch (_) {}
  }

  // Debug/utility: clear persisted role choice for current user scope.
  Future<void> clearPersistedChoice() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final roleKey = _scopedKey(_kRoleKey);
      final chosenKey = _scopedKey(_kUserChosenKey);
      await sp.remove(roleKey);
      await sp.remove(chosenKey);
    } catch (_) {}
  }

  void setRole(AppRole role, {bool userChosen = false}) {
    state = UserSession(
      role: role,
      isPremium: state.isPremium,
      userChosenRole: userChosen || state.userChosenRole,
    );
    _persistRole(role, userChosen || state.userChosenRole);
  }

  void setPremium(bool isPremium) => state = UserSession(
    role: state.role,
    isPremium: isPremium,
    userChosenRole: state.userChosenRole,
  );

  void setAll({
    required AppRole role,
    required bool isPremium,
    bool userChosen = false,
  }) {
    state = UserSession(
      role: role,
      isPremium: isPremium,
      userChosenRole: userChosen || state.userChosenRole,
    );
    _persistRole(role, userChosen || state.userChosenRole);
  }

  void setFromProfile(AppRole role, bool isPremium) {
    // Prefer backend profile after sign-in unless the user previously chose the SAME role.
    // This prevents stale persisted roles (from SharedPreferences) from overriding fresh backend data.
    if (state.userChosenRole && state.role == role) {
      // Keep the explicit user choice when it matches the backend role; update premium only.
      state = UserSession(
        role: state.role,
        isPremium: isPremium,
        userChosenRole: true,
      );
      // Note: no need to persist role change; role unchanged, chosen stays true.
      return;
    }
    // Otherwise, forcibly update to the profile role and clear the chosen flag (user hasn't re-picked yet).
    state = UserSession(role: role, isPremium: isPremium);
    _persistRole(role, false);
  }
}

AppRole? _roleFromString(String s) {
  switch (s) {
    case 'driver':
      return AppRole.driver;
    case 'fleetManager':
      return AppRole.fleetManager;
    case 'ownerOperator':
      return AppRole.ownerOperator;
    case 'broker':
      return AppRole.broker;
  }
  return null;
}

final sessionProvider = StateNotifierProvider<SessionController, UserSession>((
  ref,
) {
  return SessionController();
});
