import type { Expense } from '../types/ownerOperator';
// Using simple id generator to avoid extra deps; replace with uuid if desired
const genId = () => `exp_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

export class ExpenseService {
  async createExpense(expenseData: Partial<Expense>): Promise<Expense> {
    const expense: Expense = {
      id: genId(),
      date: expenseData.date || new Date(),
      category: (expenseData as any).category || 'other',
      amount: expenseData.amount || 0,
      description: expenseData.description || '',
      receiptUrl: expenseData.receiptUrl,
      mileage: expenseData.mileage,
      fuelGallons: expenseData.fuelGallons,
      state: expenseData.state,
      deductible: expenseData.deductible ?? true,
      metadata: expenseData.metadata,
    } as Expense;

    await this.saveExpense(expense);
    return expense;
  }

  async allocateExpenseByMileage(
    expense: Expense,
    trips: Array<{ id: string; miles: number; date: Date }>
  ): Promise<Array<{ tripId: string; allocatedAmount: number }>> {
    const relevantTrips = trips.filter((trip) => this.isSameDay(trip.date, expense.date));

    if (relevantTrips.length === 0) return [];

    const totalMiles = relevantTrips.reduce((sum, t) => sum + t.miles, 0) || 1;

    return relevantTrips.map((t) => ({
      tripId: t.id,
      allocatedAmount: (t.miles / totalMiles) * expense.amount,
    }));
  }

  async categorizeMealsAndEntertainment(
    expense: Expense
  ): Promise<{ deductibleAmount: number; limit: string }> {
    if (expense.category === 'meals') {
      return { deductibleAmount: expense.amount * 0.8, limit: '80% (DOT hours)' };
    }
    return { deductibleAmount: expense.amount, limit: '100%' };
  }

  calculateDepreciation(
    vehicleValue: number,
    monthsInService: number,
    method: 'straight-line' | 'macrs' = 'macrs'
  ): number {
    if (method === 'straight-line') {
      const yearlyDepreciation = vehicleValue / 5;
      return (yearlyDepreciation / 12) * monthsInService;
    } else {
      const macrsRates = [0.2, 0.32, 0.192, 0.1152, 0.1152, 0.0576];
      const year = Math.floor(monthsInService / 12);
      const rate = macrsRates[Math.min(year, 5)] || 0;
      return vehicleValue * rate;
    }
  }

  private isSameDay(a: Date, b: Date) {
    const ad = new Date(a);
    const bd = new Date(b);
    return (
      ad.getFullYear() === bd.getFullYear() &&
      ad.getMonth() === bd.getMonth() &&
      ad.getDate() === bd.getDate()
    );
  }

  private async saveExpense(expense: Expense): Promise<void> {
    // Placeholder for persistence
    // Integrate with your backend here
    if (process.env.NODE_ENV !== 'production') {
      // eslint-disable-next-line no-console
      console.log('[ExpenseService] Saving expense (mock):', expense.id);
    }
  }
}

export const expenseService = new ExpenseService();
