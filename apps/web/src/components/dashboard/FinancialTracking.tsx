import React, { useState } from 'react';
import { DollarSign, TrendingUp, TrendingDown, Plus } from 'lucide-react';
import type { Revenue, Expense } from '../../types/ownerOperator';
import { ExpenseEntry } from './ExpenseEntry';

interface FinancialTrackingProps {
  revenues: Revenue[];
  expenses: Expense[];
  onExpenseAdded: (expense: Expense) => void;
}

export const FinancialTracking: React.FC<FinancialTrackingProps> = ({ revenues, expenses, onExpenseAdded }) => {
  const [showExpenseEntry, setShowExpenseEntry] = useState(false);

  const totalRevenue = revenues.reduce((sum, r) => sum + r.amount, 0);
  const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0);
  const netProfit = totalRevenue - totalExpenses;
  const profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0;

  const expensesByCategory = expenses.reduce((acc, exp) => {
    (acc as any)[exp.category] = ((acc as any)[exp.category] || 0) + exp.amount;
    return acc;
  }, {} as Record<string, number>);

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-green-50 p-6 rounded-lg border border-green-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-green-600">Total Revenue</p>
              <p className="text-2xl font-bold text-green-900 mt-2">${totalRevenue.toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
            </div>
            <TrendingUp className="h-8 w-8 text-green-600" />
          </div>
        </div>
        <div className="bg-red-50 p-6 rounded-lg border border-red-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-red-600">Total Expenses</p>
              <p className="text-2xl font-bold text-red-900 mt-2">${totalExpenses.toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
            </div>
            <TrendingDown className="h-8 w-8 text-red-600" />
          </div>
        </div>
        <div className="bg-blue-50 p-6 rounded-lg border border-blue-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-blue-600">Net Profit</p>
              <p className="text-2xl font-bold text-blue-900 mt-2">${netProfit.toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
            </div>
            <DollarSign className="h-8 w-8 text-blue-600" />
          </div>
        </div>
        <div className="bg-purple-50 p-6 rounded-lg border border-purple-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-purple-600">Profit Margin</p>
              <p className="text-2xl font-bold text-purple-900 mt-2">{profitMargin.toFixed(1)}%</p>
            </div>
            <TrendingUp className="h-8 w-8 text-purple-600" />
          </div>
        </div>
      </div>

      <div className="flex justify-between items-center">
        <h2 className="text-xl font-semibold text-gray-900">Expense Management</h2>
        <button
          onClick={() => setShowExpenseEntry(true)}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
        >
          <Plus className="h-5 w-5" />
          Add Expense
        </button>
      </div>

      {showExpenseEntry && (
        <ExpenseEntry
          onClose={() => setShowExpenseEntry(false)}
          onExpenseAdded={(expense) => { onExpenseAdded(expense); setShowExpenseEntry(false); }}
        />
      )}

      <div className="bg-gray-50 p-6 rounded-lg">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Expenses by Category</h3>
        <div className="space-y-3">
          {Object.entries(expensesByCategory).map(([category, amount]) => {
            const percentage = totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0;
            return (
              <div key={category} className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex justify-between mb-1">
                    <span className="text-sm font-medium text-gray-700 capitalize">{category}</span>
                    <span className="text-sm text-gray-600">${amount.toLocaleString('en-US', { minimumFractionDigits: 2 })} ({percentage.toFixed(1)}%)</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div className="bg-blue-600 h-2 rounded-full" style={{ width: `${percentage}%` }} />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent Expenses</h3>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Description</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Deductible</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {expenses.slice(0, 10).map((expense) => (
                <tr key={expense.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{new Date(expense.date).toLocaleDateString()}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 capitalize">{expense.category}</td>
                  <td className="px-6 py-4 text-sm text-gray-900">{expense.description}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${expense.amount.toFixed(2)}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    {expense.deductible ? (
                      <span className="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">Yes</span>
                    ) : (
                      <span className="px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800">No</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default FinancialTracking;
