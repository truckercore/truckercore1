import type { BusinessMetrics, LaneProfitability, Revenue, Expense } from '../types/ownerOperator';

export class BusinessCalculations {
  calculateCostPerMile(expenses: Expense[], totalMiles: number): number {
    const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0);
    return totalMiles > 0 ? totalExpenses / totalMiles : 0;
  }

  calculateRevenuePerMile(revenues: Revenue[]): number {
    const totalRevenue = revenues.reduce((s, r) => s + r.amount, 0);
    const totalMiles = revenues.reduce((s, r) => s + r.miles, 0);
    return totalMiles > 0 ? totalRevenue / totalMiles : 0;
  }

  calculateBusinessMetrics(revenues: Revenue[], expenses: Expense[], fixedCostsMonthly: number): BusinessMetrics {
    const totalRevenue = revenues.reduce((s, r) => s + r.amount, 0);
    const totalExpenses = expenses.reduce((s, e) => s + e.amount, 0);
    const totalMiles = revenues.reduce((s, r) => s + r.miles, 0);

    const revenuePerMile = this.calculateRevenuePerMile(revenues);
    const costPerMile = this.calculateCostPerMile(expenses, totalMiles);
    const profitPerMile = revenuePerMile - costPerMile;

    const variableCosts = expenses.filter((e) => ['fuel', 'maintenance', 'tolls'].includes(e.category as any));
    const variableCostPerMile = this.calculateCostPerMile(variableCosts, totalMiles);
    const contribution = revenuePerMile - variableCostPerMile;
    const breakEvenMiles = contribution > 0 ? fixedCostsMonthly / contribution : 0;

    const operatingRatio = totalRevenue > 0 ? (totalExpenses / totalRevenue) * 100 : 0;

    return { costPerMile, revenuePerMile, profitPerMile, breakEvenMiles, operatingRatio };
  }

  analyzeLaneProfitability(revenues: Revenue[]): LaneProfitability[] {
    const laneMap = new Map<string, { loads: number; totalRevenue: number; totalMiles: number; totalCost: number }>();

    for (const r of revenues) {
      if (!r.loadId) continue;
      const laneKey = r.description; // Simplified placeholder
      const ex = laneMap.get(laneKey) || { loads: 0, totalRevenue: 0, totalMiles: 0, totalCost: 0 };
      ex.loads += 1;
      ex.totalRevenue += r.amount;
      ex.totalMiles += r.miles;
      ex.totalCost += r.miles * 1.5; // heuristic
      laneMap.set(laneKey, ex);
    }

    return Array.from(laneMap.entries())
      .map(([lane, d]) => {
        const avgRevenue = d.totalRevenue / d.loads;
        const avgMiles = d.totalMiles / d.loads;
        const avgCost = d.totalCost / d.loads;
        const profit = avgRevenue - avgCost;
        const profitMargin = avgRevenue > 0 ? (profit / avgRevenue) * 100 : 0;
        const revenuePerMile = d.totalMiles > 0 ? d.totalRevenue / d.totalMiles : 0;
        const [origin, destination] = (lane || '').split(' to ');
        return {
          origin: origin || 'Unknown',
          destination: destination || 'Unknown',
          totalLoads: d.loads,
          averageRevenue: avgRevenue,
          averageMiles: avgMiles,
          averageCost: avgCost,
          profitMargin,
          revenuePerMile,
        } as LaneProfitability;
      })
      .sort((a, b) => b.profitMargin - a.profitMargin);
  }
}

export const businessCalculations = new BusinessCalculations();
