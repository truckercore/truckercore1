import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/state/org_role_headers.dart';
import '../services/supa_client.dart';

class DelayRiskService {
  final SupaClient supa;
  final WidgetRef ref;
  DelayRiskService(this.supa, this.ref);

  Future<Map<String, dynamic>> fetchSingle(Map<String, dynamic> input) async {
    final headers = buildOrgRoleHeaders(ref);
    final res = await supa.postJson('/functions/v1/delay_risk', input, extraHeaders: headers, timeout: const Duration(milliseconds: 900));
    dev.log('delay_risk.fetch ok');
    return res;
  }

  Future<List<Map<String, dynamic>>> fetchBatch(String orgId, List<Map<String, dynamic>> items) async {
    final headers = buildOrgRoleHeaders(ref, overrideOrgId: orgId);
    final res = await supa.postJson('/functions/v1/delay_risk_batch', {
      'org_id': orgId,
      'items': items,
    }, extraHeaders: headers, timeout: const Duration(milliseconds: 1200));
    final data = (res['data'] as List).cast<Map<String, dynamic>>();
    return data;
  }
}
