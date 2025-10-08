import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import 'load_provider.dart' show apiServiceProvider; // reuse

class ExpenseNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  ExpenseNotifier(this.apiService) : super(const AsyncValue.loading());

  final ApiService apiService;
  
  Future<void> submitExpense(Expense expense) async {
    try {
      await apiService.submitExpense(expense.toJson());
      state.whenData((expenses) {
        state = AsyncValue.data([expense, ...expenses]);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadExpenses() async {
    state = const AsyncValue.loading();
    try {
      final response = await apiService.get('expenses');
      final expenses = (response['expenses'] as List?)
              ?.map((json) => Expense.fromJson(json as Map<String, dynamic>))
              .toList() ??
          <Expense>[];
      state = AsyncValue.data(expenses);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final expenseNotifierProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<List<Expense>>>((ref) {
  return ExpenseNotifier(ref.watch(apiServiceProvider));
});
