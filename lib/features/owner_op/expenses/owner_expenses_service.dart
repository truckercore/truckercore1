import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

enum ExpenseCategory {
  fuelTravel,
  maintenanceRepairs,
  insurance,
  equipmentParts,
  licensesPermits,
  operationalCosts,
  travelLodging,
  officeRecord,
  miscellaneous,
}

String categoryToDb(ExpenseCategory c) {
  switch (c) {
    case ExpenseCategory.fuelTravel:
      return 'fuel_travel';
    case ExpenseCategory.maintenanceRepairs:
      return 'maintenance_repairs';
    case ExpenseCategory.insurance:
      return 'insurance';
    case ExpenseCategory.equipmentParts:
      return 'equipment_parts';
    case ExpenseCategory.licensesPermits:
      return 'licenses_permits';
    case ExpenseCategory.operationalCosts:
      return 'operational_costs';
    case ExpenseCategory.travelLodging:
      return 'travel_lodging';
    case ExpenseCategory.officeRecord:
      return 'office_record';
    case ExpenseCategory.miscellaneous:
      return 'miscellaneous';
  }
}

class OwnerExpenseItem {
  final String id;
  final String ownerUserId;
  final String? orgId;
  final ExpenseCategory category;
  final String? description;
  final int amountCents; // store in cents for precision
  final String currency;
  final String? truckId;
  final String? driverUserId;
  final String? fileUrl;
  final DateTime addedAt;

  const OwnerExpenseItem({
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

  factory OwnerExpenseItem.fromRow(Map<String, dynamic> r) {
    return OwnerExpenseItem(
      id: r['id'] as String,
      ownerUserId: r['owner_user_id'] as String,
      orgId: r['org_id'] as String?,
      category: _fromDb(r['category'] as String),
      description: r['description'] as String?,
      amountCents: (r['amount_cents'] as num).toInt(),
      currency: (r['currency'] as String?) ?? 'USD',
      truckId: r['truck_id'] as String?,
      driverUserId: r['driver_user_id'] as String?,
      fileUrl: r['file_url'] as String?,
      addedAt: DateTime.parse(r['added_at'] as String),
    );
  }

  static ExpenseCategory _fromDb(String s) {
    switch (s) {
      case 'fuel_travel':
        return ExpenseCategory.fuelTravel;
      case 'maintenance_repairs':
        return ExpenseCategory.maintenanceRepairs;
      case 'insurance':
        return ExpenseCategory.insurance;
      case 'equipment_parts':
        return ExpenseCategory.equipmentParts;
      case 'licenses_permits':
        return ExpenseCategory.licensesPermits;
      case 'operational_costs':
        return ExpenseCategory.operationalCosts;
      case 'travel_lodging':
        return ExpenseCategory.travelLodging;
      case 'office_record':
        return ExpenseCategory.officeRecord;
      default:
        return ExpenseCategory.miscellaneous;
    }
  }
}

class OwnerExpensesService {
  OwnerExpensesService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<OwnerExpenseItem>> listMyExpenses({
    ExpenseCategory? category,
  }) async {
    final c = _maybe();
    if (c == null) return const [];
    final uid = c.auth.currentUser?.id;
    if (uid == null) return const [];
    final base = c
        .from('owner_op_expenses')
        .select()
        .eq('owner_user_id', uid);
    final filtered = category != null
        ? base.eq('category', categoryToDb(category))
        : base;
    final rowsDyn = await filtered.order('added_at', ascending: false);
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(OwnerExpenseItem.fromRow).toList();
  }

  Future<OwnerExpenseItem> addExpense({
    required ExpenseCategory category,
    String? description,
    required int amountCents,
    String currency = 'USD',
    String? truckId,
    String? driverUserId,
    String? fileUrl,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final uid = c.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final payload = {
      'owner_user_id': uid,
      'category': categoryToDb(category),
      'description': description,
      'amount_cents': amountCents,
      'currency': currency,
      'truck_id': truckId,
      'driver_user_id': driverUserId,
      'file_url': fileUrl,
    };
    final rowDyn = await c
        .from('owner_op_expenses')
        .insert(payload)
        .select()
        .single();
    final row = Map<String, dynamic>.from(rowDyn as Map);
    return OwnerExpenseItem.fromRow(row);
  }
}

final ownerExpensesServiceProvider = Provider<OwnerExpensesService>(
  (ref) => OwnerExpensesService(ref),
);
