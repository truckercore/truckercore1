import 'package:supabase_flutter/supabase_flutter.dart';

class Claims {
  final SupabaseClient _s;
  Claims(this._s);

  String get orgId {
    final v = _s.auth.currentUser?.appMetadata['app_org_id'];
    if (v == null || (v as String).isEmpty) {
      throw StateError('Missing app_org_id claim');
    }
    return v;
  }

  String get role {
    final v = _s.auth.currentUser?.appMetadata['app_role'];
    if (v == null || (v as String).isEmpty) {
      throw StateError('Missing app_role claim');
    }
    return v;
  }
}
