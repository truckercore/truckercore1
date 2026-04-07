import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_env.dart';

/// Provider for current authenticated user
final authUserProvider = StreamProvider<User?>((ref) {
  final supabase = Supabase.instance.client;
  return supabase.auth.onAuthStateChange.map((data) => data.session?.user);
});

/// Provider for checking if user has required role
final userRoleProvider = FutureProvider.family<bool, String>((ref, requiredRole) async {
  final user = await ref.watch(authUserProvider.future);
  if (user == null) return false;

  // Check user metadata for role
  final roles = user.userMetadata?['roles'] as List?;
  final primaryRole = user.userMetadata?['primary_role'] as String?;

  if (primaryRole == requiredRole) return true;
  if (roles != null && roles.contains(requiredRole)) return true;

  return false;
});

/// Provider for checking if app's default role matches user role
final isAuthorizedForAppProvider = FutureProvider<bool>((ref) async {
  final defaultRole = AppEnv.defaultRole;
  if (defaultRole.isEmpty) return true; // No role restriction

  return ref.watch(userRoleProvider(defaultRole).future);
});
