import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/design_partner.dart';
import '../services/design_partners_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

final designPartnersServiceProvider = Provider<DesignPartnersService>(
  (ref) => DesignPartnersService(ref.watch(supabaseClientProvider)),
);

// All partners (optionally filtered on watch)
final designPartnersProvider = FutureProvider.family<List<DesignPartner>, String?>(
  (ref, status) => ref.read(designPartnersServiceProvider).list(status: status),
);

// Active design partner for an org
final activeDesignPartnerProvider = FutureProvider.family<DesignPartner?, String>(
  (ref, orgId) => ref.read(designPartnersServiceProvider).getActiveByOrg(orgId),
);
