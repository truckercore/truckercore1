import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/expense.dart';
import 'package:truckercore1/providers/api_provider.dart';

final expensesProvider = FutureProvider.family<List<Expense>, String?>((ref, driverId) async {
  final apiService = ref.watch(apiServiceProvider);
  final res = await apiService.fetchExpenses(driverId: driverId);
  return res.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
});

final submitExpenseProvider = Provider<Future<bool> Function(Expense)>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return (expense) async {
    await apiService.submitExpense(expense.toJson());
    return true;
  };
});
