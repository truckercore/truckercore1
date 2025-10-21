// lib/services/ai_finance_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common/config/app_config.dart';

class AiFinancialRecommendation {
  final String id;
  final String userId;
  final String kind; // fuel|detention|route|margin|hos
  final String text;
  final int projectedSavingsCents;
  final DateTime createdAt;
  final String? loadId;
  const AiFinancialRecommendation({
    required this.id,
    required this.userId,
    required this.kind,
    required this.text,
    required this.projectedSavingsCents,
    required this.createdAt,
    this.loadId,
  });
  static AiFinancialRecommendation fromMap(Map<String, dynamic> r) =>
      AiFinancialRecommendation(
        id: r['id']?.toString() ?? '',
        userId: r['user_id']?.toString() ?? '',
        kind: r['kind']?.toString() ?? 'general',
        text: r['text']?.toString() ?? '',
        projectedSavingsCents:
            (r['projected_savings_cents'] as int?) ??
            ((r['savings_usd'] as num?)?.toDouble() ?? 0 * 100).round(),
        createdAt:
            DateTime.tryParse(r['created_at']?.toString() ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
        loadId: r['load_id']?.toString(),
      );
}

class AiFinanceService {
  AiFinanceService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<AiFinancialRecommendation>> lastRecsForUser(
    String userId, {
    int limit = 10,
  }) async {
    final c = _maybe();
    if (c == null) return const [];
    final rows = await c
        .from('ai_financial_recommendations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    final list = (rows as List?) ?? const [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(AiFinancialRecommendation.fromMap)
        .toList();
  }

  Future<List<AiFinancialRecommendation>> topSavingsThisWeek({
    int limit = 3,
  }) async {
    final c = _maybe();
    if (c == null) return const [];
    final now = DateTime.now().toUtc();
    final since = now.subtract(const Duration(days: 7));
    final rows = await c
        .from('ai_financial_recommendations')
        .select()
        .gte('created_at', since.toIso8601String())
        .order('projected_savings_cents', ascending: false)
        .limit(limit);
    final list = (rows as List?) ?? const [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(AiFinancialRecommendation.fromMap)
        .toList();
  }
}

final aiFinanceServiceProvider = Provider<AiFinanceService>(
  (ref) => AiFinanceService(ref),
);
