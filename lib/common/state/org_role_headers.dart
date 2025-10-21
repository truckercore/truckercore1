import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_role.dart';
import 'session_provider.dart';

/// Builds extra headers to pass org/roles context to Edge Functions and APIs that read headers.
/// Note: RLS in Postgres uses JWT claims; these headers are for function/webhook context only.
Map<String, String> buildOrgRoleHeaders(WidgetRef ref, {String? overrideOrgId}) {
  final user = Supabase.instance.client.auth.currentUser;
  final session = ref.read(sessionProvider);
  final roles = <String>{};
  // Minimal mapping from AppRole to backend string roles
  String mapRole(AppRole r) {
    switch (r) {
      case AppRole.driver:
        return 'driver';
      case AppRole.fleetManager:
        return 'fleet_manager';
      case AppRole.ownerOperator:
        return 'owner_op';
      case AppRole.broker:
        return 'broker';
    }
  }
  roles.add(mapRole(session.role));
  final orgId = overrideOrgId ?? user?.userMetadata?['org_id']?.toString();
  final headers = <String, String>{
    if (orgId != null) 'x-app-org-id': orgId,
    'x-app-roles': roles.join(','),
  };
  return headers;
}
