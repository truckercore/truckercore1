import React, { useEffect, useState } from 'react';
import { TrendingUp, DollarSign, Target, BarChart3 } from 'lucide-react';
import type { Revenue, Expense, BusinessMetrics, LaneProfitability } from '../../types/ownerOperator';
import { businessCalculations } from '../../utils/calculations';

interface BusinessIntelligenceProps {
  revenues: Revenue[];
  expenses: Expense[];
}

export const BusinessIntelligence: React.FC<BusinessIntelligenceProps> = ({ revenues, expenses }) => {
  const [metrics, setMetrics] = useState<BusinessMetrics | null>(null);
  const [laneProfitability, setLaneProfitability] = useState<LaneProfitability[]>([]);
  const [fixedCostsMonthly, setFixedCostsMonthly] = useState(5000);
  const [timeRange, setTimeRange] = useState<'week' | 'month' | 'quarter' | 'year'>('month');

  useEffect(() => {
    calculateMetrics();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [revenues, expenses, fixedCostsMonthly, timeRange]);

  const calculateMetrics = () => {
    const filteredRevenues = filterByTimeRange(revenues);
    const filteredExpenses = filterByTimeRange(expenses);
    const bm = businessCalculations.calculateBusinessMetrics(filteredRevenues, filteredExpenses, fixedCostsMonthly);
    setMetrics(bm);
    const lanes = businessCalculations.analyzeLaneProfitability(filteredRevenues);
    setLaneProfitability(lanes);
  };

  const filterByTimeRange = <T extends { date: Date }>(items: T[]): T[] => {
    const now = new Date();
    const cutoff = new Date();
    switch (timeRange) {
      case 'week':
        cutoff.setDate(now.getDate() - 7);
        break;
      case 'month':
        cutoff.setMonth(now.getMonth() - 1);
        break;
      case 'quarter':
        cutoff.setMonth(now.getMonth() - 3);
        break;
      case 'year':
        cutoff.setFullYear(now.getFullYear() - 1);
        break;
    }
    return items.filter((i) => new Date(i.date) >= cutoff);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900">Business Intelligence</h2>
        <div className="flex gap-2">
          {(['week', 'month', 'quarter', 'year'] as const).map((range) => (
            <button
              key={range}
              onClick={() => setTimeRange(range)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                timeRange === range ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {range.charAt(0).toUpperCase() + range.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {metrics && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <MetricCard title="Revenue Per Mile" value={`$${metrics.revenuePerMile.toFixed(2)}`} icon={<DollarSign className="h-6 w-6" />} color="green" subtitle="Average rate" />
          <MetricCard title="Cost Per Mile" value={`$${metrics.costPerMile.toFixed(2)}`} icon={<TrendingUp className="h-6 w-6" />} color="red" subtitle="All-in operating cost" />
          <MetricCard title="Profit Per Mile" value={`$${metrics.profitPerMile.toFixed(2)}`} icon={<Target className="h-6 w-6" />} color="blue" subtitle={`${((metrics.profitPerMile / (metrics.revenuePerMile || 1)) * 100).toFixed(1)}% margin`} />
          <MetricCard title="Operating Ratio" value={`${metrics.operatingRatio.toFixed(1)}%`} icon={<BarChart3 className="h-6 w-6" />} color={metrics.operatingRatio < 80 ? 'green' : metrics.operatingRatio < 95 ? 'yellow' : 'red'} subtitle={metrics.operatingRatio < 80 ? 'Excellent' : metrics.operatingRatio < 95 ? 'Good' : 'Needs improvement'} />
        </div>
      )}

      <div className="bg-gradient-to-br from-purple-50 to-pink-50 rounded-lg p-6 border border-purple-200">
        <h3 className="text-xl font-semibold text-gray-900 mb-4">Break-Even Analysis</h3>
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-2">Monthly Fixed Costs</label>
          <div className="flex items-center gap-2">
            <span className="text-gray-500">$</span>
            <input type="number" value={fixedCostsMonthly} onChange={(e) => setFixedCostsMonthly(Number(e.target.value))} className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" placeholder="5000" />
            <span className="text-sm text-gray-600">(Insurance, truck payment, permits, etc.)</span>
          </div>
        </div>
        {metrics && (
          <div className="space-y-4">
            <div className="bg-white rounded-lg p-4">
              <div className="flex justify-between items-center">
                <div>
                  <p className="text-sm text-gray-600">Break-Even Miles Per Month</p>
                  <p className="text-3xl font-bold text-purple-700">{metrics.breakEvenMiles.toLocaleString('en-US', { maximumFractionDigits: 0 })}</p>
                </div>
                <Target className="h-12 w-12 text-purple-400" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-white rounded-lg p-4">
                <p className="text-sm text-gray-600">Weekly Target</p>
                <p className="text-xl font-bold text-gray-900">{(metrics.breakEvenMiles / 4.33).toLocaleString('en-US', { maximumFractionDigits: 0 })} miles</p>
              </div>
              <div className="bg-white rounded-lg p-4">
                <p className="text-sm text-gray-600">Daily Target</p>
                <p className="text-xl font-bold text-gray-900">{(metrics.breakEvenMiles / 30).toLocaleString('en-US', { maximumFractionDigits: 0 })} miles</p>
              </div>
            </div>
            <div className="bg-purple-100 p-4 rounded-lg">
              <p className="text-sm text-purple-900">
                <strong>Break-even calculation:</strong> Drive {metrics.breakEvenMiles.toLocaleString()} miles per month at ${metrics.revenuePerMile.toFixed(2)}/mile with ${metrics.costPerMile.toFixed(2)}/mile in variable costs to cover ${fixedCostsMonthly.toLocaleString()} in fixed monthly expenses.
              </p>
            </div>
          </div>
        )}
      </div>

      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-xl font-semibold text-gray-900 mb-4">Lane Profitability Analysis</h3>
        {laneProfitability.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Lane</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Loads</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Avg Revenue</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Avg Miles</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Rev/Mile</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Profit Margin</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {laneProfitability.map((lane, idx) => (
                  <tr key={idx} className="hover:bg-gray-50">
                    <td className="px-6 py-4 text-sm text-gray-900">
                      <div className="font-medium">{lane.origin}</div>
                      <div className="text-gray-500">→ {lane.destination}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">{lane.totalLoads}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">${lane.averageRevenue.toLocaleString('en-US', { minimumFractionDigits: 2 })}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">{lane.averageMiles.toFixed(0)}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900 text-right">${lane.revenuePerMile.toFixed(2)}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-right">
                      <span className={`px-2 py-1 rounded-full text-xs font-semibold ${
                        lane.profitMargin > 20 ? 'bg-green-100 text-green-800' : lane.profitMargin > 10 ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'
                      }`}>{lane.profitMargin.toFixed(1)}%</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="text-center py-8 text-gray-600">
            <p>No lane data available</p>
            <p className="text-sm mt-2">Complete more loads to see lane profitability analysis</p>
          </div>
        )}
      </div>

      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-xl font-semibold text-gray-900 mb-4">Cost Breakdown</h3>
        <div className="space-y-4">
          {getCostBreakdown(expenses).map((item) => (
            <div key={item.category}>
              <div className="flex justify-between mb-2">
                <span className="text-sm font-medium text-gray-700 capitalize">{item.category}</span>
                <span className="text-sm text-gray-900">${item.amount.toLocaleString('en-US', { minimumFractionDigits: 2 })} ({item.percentage.toFixed(1)}%)</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-3">
                <div className="bg-gradient-to-r from-blue-500 to-purple-500 h-3 rounded-full transition-all duration-300" style={{ width: `${item.percentage}%` }} />
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-blue-50 rounded-lg p-6 border border-blue-200">
        <h3 className="text-xl font-semibold text-gray-900 mb-4">Recommendations</h3>
        <div className="space-y-3">
          {generateRecommendations(metrics).map((rec, idx) => (
            <div key={idx} className="flex items-start gap-3">
              <div className="flex-shrink-0 w-6 h-6 rounded-full bg-blue-600 text-white flex items-center justify-center text-sm font-bold">{idx + 1}</div>
              <p className="text-sm text-gray-700">{rec}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const MetricCard: React.FC<{ title: string; value: string; icon: React.ReactNode; color: 'green' | 'red' | 'blue' | 'yellow' | 'purple'; subtitle?: string; }> = ({ title, value, icon, color, subtitle }) => {
  const colorClasses: Record<string, string> = {
    green: 'from-green-50 to-emerald-50 border-green-200 text-green-600',
    red: 'from-red-50 to-rose-50 border-red-200 text-red-600',
    blue: 'from-blue-50 to-indigo-50 border-blue-200 text-blue-600',
    yellow: 'from-yellow-50 to-amber-50 border-yellow-200 text-yellow-600',
    purple: 'from-purple-50 to-pink-50 border-purple-200 text-purple-600',
  };
  return (
    <div className={`bg-gradient-to-br ${colorClasses[color]} rounded-lg p-6 border`}>
      <div className="flex items-center justify-between mb-2">
        <h4 className="text-sm font-medium text-gray-600">{title}</h4>
        <div>{icon}</div>
      </div>
      <p className="text-3xl font-bold text-gray-900">{value}</p>
      {subtitle && <p className="text-sm text-gray-600 mt-1">{subtitle}</p>}
    </div>
  );
};

const getCostBreakdown = (expenses: Expense[]): Array<{ category: string; amount: number; percentage: number }> => {
  const total = expenses.reduce((s, e) => s + e.amount, 0);
  const byCat = expenses.reduce((acc, e) => {
    acc[e.category] = (acc[e.category] || 0) + e.amount;
    return acc;
  }, {} as Record<string, number>);
  return Object.entries(byCat)
    .map(([category, amount]) => ({ category, amount, percentage: total > 0 ? (amount / total) * 100 : 0 }))
    .sort((a, b) => b.amount - a.amount);
};

const generateRecommendations = (metrics: BusinessMetrics | null): string[] => {
  if (!metrics) return [];
  const recs: string[] = [];
  if (metrics.operatingRatio > 95) recs.push('Your operating ratio is high (>95%). Focus on reducing expenses or increasing rates to improve profitability.');
  if (metrics.profitPerMile < 0.5) recs.push('Profit per mile is below industry average. Consider negotiating better rates or reducing variable costs like fuel consumption.');
  if (metrics.breakEvenMiles > 10000) recs.push('High break-even point suggests heavy fixed costs. Review insurance, truck payments, and other fixed expenses for potential savings.');
  if (metrics.revenuePerMile < 2.0) recs.push('Revenue per mile is below $2.00. Focus on higher-paying lanes and avoid low-rate freight to improve margins.');
  if (recs.length === 0) recs.push('Your operation is performing well! Continue monitoring metrics and focus on the most profitable lanes.');
  return recs;
};

export default BusinessIntelligence;
