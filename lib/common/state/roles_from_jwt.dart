import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_role.dart';
import '../state/session_provider.dart';

class JwtRoles {
  final List<AppRole> roles;
  final AppRole? primary;
  const JwtRoles({required this.roles, this.primary});
}

AppRole? _roleFromString(String s) {
  switch (s.toLowerCase()) {
    case 'driver':
      return AppRole.driver;
    case 'owner_op':
    case 'owner-operator':
    case 'owneroperator':
      return AppRole.ownerOperator;
    case 'carrier':
      return AppRole
          .fleetManager; // carrier maps to fleet manager dashboard in this app
    case 'broker':
      return AppRole.broker;
  }
  return null;
}

final jwtRolesProvider = Provider<JwtRoles>((ref) {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.appMetadata;
    Map<String, dynamic>? claims;
    if (meta is Map) {
      final m = meta as Map;
      final dynamic jwt = m['claims'] ?? m['jwt'];
      if (jwt is Map) {
        claims = Map<String, dynamic>.from(jwt);
      }
    }
    // Supabase Flutter exposes raw access token via currentSession; try that too
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (claims == null && token is String && token.split('.').length == 3) {
      final payload = token.split('.')[1];
      final norm = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(norm));
      claims = jsonDecode(decoded) as Map<String, dynamic>;
    }
    final rolesDyn = claims?['app_roles'];
    final primaryDyn = claims?['app_primary_role'];
    final roles = <AppRole>[];
    if (rolesDyn is List) {
      for (final r in rolesDyn) {
        final rr = _roleFromString(r.toString());
        if (rr != null && !roles.contains(rr)) roles.add(rr);
      }
    }
    final primary = primaryDyn is String ? _roleFromString(primaryDyn) : null;
    return JwtRoles(roles: roles, primary: primary);
  } catch (_) {
    return const JwtRoles(roles: []);
  }
});

// Enhances availableRolesProvider by preferring JWT roles if present
final comboAvailableRolesProvider = Provider<List<AppRole>>((ref) {
  final jwt = ref.watch(jwtRolesProvider);
  if (jwt.roles.isNotEmpty) return jwt.roles;
  // fallback to prior heuristic
  final session = ref.watch(sessionProvider);
  if (session.role == AppRole.broker) {
    return const [AppRole.broker, AppRole.fleetManager];
  }
  return [session.role];
});

// Persist and expose current role selection
final currentRoleProvider =
    StateNotifierProvider<_CurrentRoleController, AppRole>((ref) {
      final session = ref.watch(sessionProvider);
      // Initialize from session.role only. Do not auto-override with JWT here.
      // Any JWT-based selection must be explicitly applied in HomeGate with guards.
      final initial = session.role;
      return _CurrentRoleController(ref, initial);
    });

class _CurrentRoleController extends StateNotifier<AppRole> {
  _CurrentRoleController(this._ref, AppRole initial) : super(initial) {
    // Ensure we stop using _ref/state after disposal
    _ref.onDispose(() {
      _disposed = true;
    });
  }
  final Ref _ref;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void set(AppRole r, {bool userChosen = false}) {
    if (_disposed) {
      // ignore: avoid_print
      print('[role] set($r) ignored because _CurrentRoleController is disposed');
      return;
    }
    // keep session in sync as single source for rest of app
    _ref.read(sessionProvider.notifier).setRole(r, userChosen: userChosen);
    if (_disposed) return; // guard in case dispose happened during setRole
    state = r;
  }
}
