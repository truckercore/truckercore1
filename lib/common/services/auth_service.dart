import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

// Stream of auth state changes (signed in/out)
final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final configured =
      cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
  if (!configured) {
    // Without Supabase, expose a simple "signed out" stream.
    return Stream<AuthState>.value(const AuthState.signedOut());
  }
  final client = Supabase.instance.client;
  return client.auth.onAuthStateChange.map(
    (event) => event.session == null
        ? const AuthState.signedOut()
        : const AuthState.signedIn(),
  );
});

class AuthState {
  final bool isLoggedIn;
  const AuthState._(this.isLoggedIn);
  const AuthState.signedIn() : this._(true);
  const AuthState.signedOut() : this._(false);
}

class AuthService {
  AuthService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybeClient() {
    final cfg = _ref.read(appConfigProvider);
    final configured =
        !cfg.useMockData &&
        cfg.supabaseUrl.isNotEmpty &&
        cfg.supabaseAnonKey.isNotEmpty;
    if (!configured) return null;
    return Supabase.instance.client;
  }

  Future<void> signIn(String email, String password) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password are required');
    }
    final client = _maybeClient();
    if (client == null) {
      // No backend configured or we are in mock mode; simulate success.
      return;
    }
    try {
      final res = await client.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );
      if (res.session == null) {
        throw Exception('Login failed');
      }
    } catch (e) {
      final msg = e.toString();
      // Provide clearer message for common network/retryable fetch errors
      if (msg.contains('Failed to fetch') ||
          msg.contains('AuthRetryableFetchException')) {
        throw Exception(
          'Network error: Unable to reach the authentication server. Please check your internet connection, VPN/proxy, and SUPABASE_URL.',
        );
      }
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password are required');
    }
    final client = _maybeClient();
    if (client == null) {
      // No backend configured or we are in mock mode; simulate success.
      return;
    }
    try {
      final res = await client.auth.signUp(
        email: trimmedEmail,
        password: password,
      );
      if (res.user == null) {
        throw Exception('Sign-up failed');
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed to fetch') ||
          msg.contains('AuthRetryableFetchException')) {
        throw Exception(
          'Network error: Unable to reach the authentication server. Please check your internet connection, VPN/proxy, and SUPABASE_URL.',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    final client = _maybeClient();
    if (client == null) return; // nothing to do when not configured
    await client.auth.signOut();
  }

  bool get isLoggedInNow {
    final client = _maybeClient();
    if (client == null) return false;
    return client.auth.currentUser != null;
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));
