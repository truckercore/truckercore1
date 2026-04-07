import 'package:supabase_flutter/supabase_flutter.dart';

/// Safe accessors that do not throw when Supabase.initialize() was skipped.
class SupabaseSafe {
  static bool get isReady {
    try {
      // Accessing instance before init throws. Guard with try/catch.
      // We also ensure client isn't null by touching a trivial field.
      final _ = Supabase.instance.client; // may throw if not initialized
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns Supabase client if initialized; otherwise null.
  static SupabaseClient? get clientOrNull {
    if (!isReady) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Executes [fn] only if Supabase is initialized, otherwise returns null.
  static Future<T?> runIfReady<T>(
    Future<T> Function(SupabaseClient c) fn,
  ) async {
    final c = clientOrNull;
    if (c == null) return null;
    return await fn(c);
  }
}
