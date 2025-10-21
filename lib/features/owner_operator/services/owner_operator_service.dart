import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/financial_summary.dart';

final ownerOperatorServiceProvider = Provider<OwnerOperatorService>((ref) {
  return OwnerOperatorService();
});

class OwnerOperatorService {
  /// Get financial summary for owner operator
  Future<FinancialSummary> getFinancialSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await SupaClient.rpc('get_owner_operator_financials', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });

    return FinancialSummary.fromJson(response as Map<String, dynamic>);
  }

  /// Get load settlements
  Future<List<Settlement>> getSettlements({
    required DateTime startDate,
    required DateTime endDate,
    String? status,
  }) async {
    var query = SupaClient.from('settlements')
        .select('*')
        .gte('settlement_date', startDate.toIso8601String())
        .lte('settlement_date', endDate.toIso8601String())
        .order('settlement_date', ascending: false);

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query;
    return (response as List).map((s) => Settlement.fromJson(s)).toList();
  }

  /// Get revenue by load
  Future<List<LoadRevenue>> getRevenueByLoad({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await SupaClient.from('load_revenues')
        .select('*')
        .gte('completed_at', startDate.toIso8601String())
        .lte('completed_at', endDate.toIso8601String())
        .order('completed_at', ascending: false);

    return (response as List).map((r) => LoadRevenue.fromJson(r)).toList();
  }

  /// Get expense breakdown
  Future<ExpenseBreakdown> getExpenseBreakdown({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await SupaClient.rpc('calculate_expense_breakdown', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });

    return ExpenseBreakdown.fromJson(response as Map<String, dynamic>);
  }

  /// Record expense
  Future<void> recordExpense({
    required String category,
    required double amount,
    required DateTime date,
    String? description,
    String? receiptUrl,
    String? vehicleId,
  }) async {
    await SupaClient.from('expenses').insert({
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'receipt_url': receiptUrl,
      'vehicle_id': vehicleId,
    });
  }

  /// Get profit & loss statement
  Future<ProfitLossStatement> getProfitLoss({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await SupaClient.rpc('generate_profit_loss', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });

    return ProfitLossStatement.fromJson(response as Map<String, dynamic>);
  }

  /// Get tax documents (1099, etc.)
  Future<List<TaxDocument>> getTaxDocuments(int year) async {
    final response = await SupaClient.from('tax_documents')
        .select('*')
        .eq('year', year)
        .order('created_at', ascending: false);

    return (response as List).map((d) => TaxDocument.fromJson(d)).toList();
  }

  /// Export financial report
  Future<String> exportFinancialReport({
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
    String format = 'pdf',
  }) async {
    final response = await SupaClient.functions('export-financial-report', {
      'report_type': reportType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'format': format,
    });

    return response.data['download_url'] as String;
  }

  /// Get fuel card transactions
  Future<List<FuelTransaction>> getFuelTransactions({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await SupaClient.from('fuel_transactions')
        .select('*')
        .gte('transaction_date', startDate.toIso8601String())
        .lte('transaction_date', endDate.toIso8601String())
        .order('transaction_date', ascending: false);

    return (response as List).map((t) => FuelTransaction.fromJson(t)).toList();
  }

  /// Get revenue per mile analysis
  Future<RevenuePerMileAnalysis> getRevenuePerMile({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await SupaClient.rpc('calculate_revenue_per_mile', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });

    return RevenuePerMileAnalysis.fromJson(response as Map<String, dynamic>);
  }
}
