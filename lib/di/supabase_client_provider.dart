import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Nullable Supabase client provider.
/// If Supabase.initialize() hasn't been called, returns null instead of throwing.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});
