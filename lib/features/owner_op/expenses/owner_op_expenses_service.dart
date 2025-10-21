import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

/// Expense item for Owner-Operators (matches public.owner_op_expenses schema)
class ExpenseItem {
  final String id;
  final String ownerUserId;
  final String? orgId;
  final String category; // fuel_travel, maintenance_repairs, insurance, etc.
  final String? description;
  final int amountCents;
  final String currency;
  final String? truckId;
  final String? driverUserId;
  final String? fileUrl;
  final DateTime addedAt;

  const ExpenseItem({
    required this.id,
    required this.ownerUserId,
    required this.orgId,
    required this.category,
    required this.description,
    required this.amountCents,
    required this.currency,
    required this.truckId,
    required this.driverUserId,
    required this.fileUrl,
    required this.addedAt,
  });

  static ExpenseItem fromMap(Map<String, dynamic> row) {
    return ExpenseItem(
      id: row['id'] as String,
      ownerUserId: row['owner_user_id'] as String,
      orgId: row['org_id'] as String?,
      category: row['category'] as String,
      description: row['description'] as String?,
      amountCents: (row['amount_cents'] as num).toInt(),
      currency: (row['currency'] as String?) ?? 'USD',
      truckId: row['truck_id'] as String?,
      driverUserId: row['driver_user_id'] as String?,
      fileUrl: row['file_url'] as String?,
      addedAt: DateTime.parse(row['added_at'] as String),
    );
  }

  Map<String, dynamic> toInsert() => {
    'owner_user_id': ownerUserId,
    'org_id': orgId,
    'category': category,
    'description': description,
    'amount_cents': amountCents,
    'currency': currency,
    'truck_id': truckId,
    'driver_user_id': driverUserId,
    'file_url': fileUrl,
    // added_at default now()
  };
}

class OwnerOpExpensesService {
  OwnerOpExpensesService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    final ok = cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
    return ok ? Supabase.instance.client : null;
  }

  Future<ExpenseItem> addExpense({
    required String category,
    required int amountCents,
    String currency = 'USD',
    String? description,
    String? fileUrl,
    String? truckId,
  }) async {
    final c = _maybe();
    if (c == null) {
      // Offline/demo fallback: throw to signal not configured
      throw Exception('Supabase not configured');
    }
    final uid = c.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final payload = {
      'owner_user_id': uid,
      'category': category,
      'description': description,
      'amount_cents': amountCents,
      'currency': currency,
      'truck_id': truckId,
      'file_url': fileUrl,
    };
    final rowDyn = await c
        .from('owner_op_expenses')
        .insert(payload)
        .select()
        .single();
    return ExpenseItem.fromMap(Map<String, dynamic>.from(rowDyn as Map));
  }

  Future<List<ExpenseItem>> listRecent({int limit = 50}) async {
    final c = _maybe();
    if (c == null) return const [];
    final uid = c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rowsDyn = await c
        .from('owner_op_expenses')
        .select()
        .eq('owner_user_id', uid)
        .order('added_at', ascending: false)
        .limit(limit);
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(ExpenseItem.fromMap).toList();
  }

  Future<List<ExpenseItem>> listBetween(DateTime start, DateTime end) async {
    final c = _maybe();
    if (c == null) return const [];
    final uid = c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rowsDyn = await c
        .from('owner_op_expenses')
        .select()
        .eq('owner_user_id', uid)
        .gte('added_at', start.toUtc().toIso8601String())
        .lte('added_at', end.toUtc().toIso8601String())
        .order('added_at');
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(ExpenseItem.fromMap).toList();
  }

  /// Returns weekly sums (Monday-start) for expenses in cents within range.
  Future<Map<DateTime, int>> weeklyExpenseSums(
    DateTime start,
    DateTime end,
  ) async {
    final items = await listBetween(start, end);
    final map = <DateTime, int>{};
    for (final e in items) {
      final d = _mondayOfWeek(e.addedAt.toUtc());
      map[d] = (map[d] ?? 0) + e.amountCents;
    }
    return map;
  }

  DateTime _mondayOfWeek(DateTime utc) {
    final dow = utc.weekday; // Mon=1 .. Sun=7
    final delta = dow - 1;
    final day = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
    ).subtract(Duration(days: delta));
    return day;
  }

  /// Very simple recurring forecast (stub): repeats last 4 weeks average.
  Future<List<int>> forecastOutflowWeekly({
    int weeks = 8,
    DateTime? pivot,
  }) async {
    final now = pivot ?? DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 28));
    final sums = await weeklyExpenseSums(start, now);
    if (sums.isEmpty) return List<int>.filled(weeks, 0);
    final avg = sums.values.fold<int>(0, (a, b) => a + b) ~/ sums.length;
    return List<int>.filled(weeks, avg);
  }
}

final ownerOpExpensesServiceProvider = Provider<OwnerOpExpensesService>(
  (ref) => OwnerOpExpensesService(ref),
);
