import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Expose the initialized Supabase client through Riverpod only.
final supabaseClientProvider = Provider((ref) {
  return Supabase.instance.client;
});
