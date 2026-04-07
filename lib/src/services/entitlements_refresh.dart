// Dart
import 'package:supabase_flutter/supabase_flutter.dart';

class EntitlementsRefresh {
  static Future<void> refresh() async {
    final sb = Supabase.instance.client;
    await sb.auth.refreshSession();
    await sb
        .from('profiles')
        .select('app_tier, app_is_premium')
        .eq('id', sb.auth.currentUser!.id)
        .maybeSingle();
  }
}
