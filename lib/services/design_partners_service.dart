import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart' as app_log;
import '../models/design_partner.dart';

class DesignPartnersService {
  DesignPartnersService(this._client);
  final SupabaseClient _client;

  static const table = 'design_partners';

  // List all (optionally filter by status)
  Future<List<DesignPartner>> list({String? status}) async {
    try {
      final builder = _client.from(table).select();
      final List data = status == null
          ? await builder.order('created_at', ascending: false)
          : await builder.eq('status', status).order('created_at', ascending: false);
      return data.map((r) => DesignPartner.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e, st) {
      app_log.AppLogger.warn('design_partners.list failed', e, st);
      rethrow;
    }
  }

  // Active per org
  Future<DesignPartner?> getActiveByOrg(String orgId) async {
    try {
      final List rows = await _client
          .from(table)
          .select()
          .eq('org_id', orgId)
          .eq('status', 'active')
          .limit(1);
      if (rows.isEmpty) return null;
      return DesignPartner.fromJson(Map<String, dynamic>.from(rows.first as Map));
    } catch (e, st) {
      app_log.AppLogger.warn('design_partners.getActiveByOrg failed', e, st);
      rethrow;
    }
  }

  // Upsert via RPC (preferred) else fallback to insert/update
  Future<String> upsert({
    required String orgId,
    required DateTime pilotStart,
    DateTime? pilotEnd,
    Map<String, dynamic>? successCriteria,
    String status = 'active',
  }) async {
    // Try RPC first
    try {
      final dynamic resp = await _client.rpc('svc_dp_upsert', params: {
        'p_org': orgId,
        'p_pilot_start': pilotStart.toIso8601String(),
        'p_pilot_end': pilotEnd?.toIso8601String(),
        'p_success': successCriteria ?? <String, dynamic>{},
        'p_status': status,
      });
      if (resp is String && resp.isNotEmpty) return resp;
      if (resp is Map && resp['id'] is String) return resp['id'] as String;
    } catch (e, st) {
      app_log.AppLogger.warn('svc_dp_upsert not available; falling back', e, st);
    }

    // Fallback: try update existing active, else insert new
    final existing = await getActiveByOrg(orgId);
    if (existing != null) {
      await _client.from(table).update({
        'pilot_start': pilotStart.toIso8601String(),
        'pilot_end': pilotEnd?.toIso8601String(),
        'success_criteria': successCriteria ?? <String, dynamic>{},
        'status': status,
      }).eq('id', existing.id);
      return existing.id;
    } else {
      final List rows = await _client
          .from(table)
          .insert({
            'org_id': orgId,
            'pilot_start': pilotStart.toIso8601String(),
            'pilot_end': pilotEnd?.toIso8601String(),
            'success_criteria': successCriteria ?? <String, dynamic>{},
            'status': status,
          })
          .select('id')
          .limit(1);
      return (rows.first as Map)['id'] as String;
    }
  }

  // Set status (complete/fail) via RPC else fallback
  Future<void> setStatus({
    required String orgId,
    required String status, // 'active'|'completed'|'failed'
    DateTime? pilotEnd,
  }) async {
    // Try RPC first
    try {
      await _client.rpc('svc_dp_set_status', params: {
        'p_org': orgId,
        'p_status': status,
        'p_pilot_end': pilotEnd?.toIso8601String(),
      });
      return;
    } catch (e, st) {
      app_log.AppLogger.warn('svc_dp_set_status not available; falling back', e, st);
    }

    // Fallback: update active row for org
    await _client
        .from(table)
        .update({
          'status': status,
          if (pilotEnd != null) 'pilot_end': pilotEnd.toIso8601String(),
        })
        .eq('org_id', orgId)
        .eq('status', 'active');
  }
}
