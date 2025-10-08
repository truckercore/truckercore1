import type { IFTAReport, StateIFTA, Form2290Data, TaxEstimate, Form1099Data } from '../types/ownerOperator';

export class TaxService {
  // IFTA tax rates by state (2024 sample rates; update as needed)
  private iftaTaxRates: Record<string, number> = {
    AL: 0.29, AK: 0.0895, AZ: 0.31, AR: 0.285, CA: 0.537,
    CO: 0.2725, CT: 0.499, DE: 0.28, FL: 0.335, GA: 0.374,
    ID: 0.32, IL: 0.467, IN: 0.54, IA: 0.325, KS: 0.26,
    KY: 0.286, LA: 0.201, ME: 0.314, MD: 0.3785, MA: 0.24,
    MI: 0.277, MN: 0.286, MS: 0.184, MO: 0.1750, MT: 0.3375,
    NE: 0.2880, NV: 0.275, NH: 0.222, NJ: 0.435, NM: 0.1875,
    NY: 0.4525, NC: 0.3825, ND: 0.23, OH: 0.47, OK: 0.20,
    OR: 0.38, PA: 0.588, RI: 0.35, SC: 0.28, SD: 0.30,
    TN: 0.27, TX: 0.20, UT: 0.3650, VT: 0.3010, VA: 0.262,
    WA: 0.494, WV: 0.3570, WI: 0.329, WY: 0.24,
  };

  async generateIFTAReport(
    quarter: string,
    year: number,
    trips: Array<{ state: string; miles: number }>,
    fuelPurchases: Array<{ state: string; gallons: number }>
  ): Promise<IFTAReport> {
    const stateData = new Map<string, { miles: number; gallons: number }>();

    trips.forEach((trip) => {
      const existing = stateData.get(trip.state) || { miles: 0, gallons: 0 };
      stateData.set(trip.state, { ...existing, miles: existing.miles + trip.miles });
    });

    fuelPurchases.forEach((purchase) => {
      const existing = stateData.get(purchase.state) || { miles: 0, gallons: 0 };
      stateData.set(purchase.state, { ...existing, gallons: existing.gallons + purchase.gallons });
    });

    const stateBreakdown: StateIFTA[] = Array.from(stateData.entries()).map(([state, data]) => {
      const taxRate = this.iftaTaxRates[state] ?? 0.3;
      const mpg = data.miles / Math.max(data.gallons, 1);
      const gallonsConsumed = data.miles / Math.max(mpg, 1);
      const taxableGallons = Math.max(0, gallonsConsumed - data.gallons);

      return {
        state,
        miles: data.miles,
        fuelGallons: data.gallons,
        taxRate,
        taxOwed: taxableGallons * taxRate,
      };
    });

    const totalTax = stateBreakdown.reduce((sum, s) => sum + s.taxOwed, 0);

    return {
      quarter,
      year,
      stateBreakdown,
      totalTax,
    };
  }

  calculateForm2290(
    vin: string,
    grossWeight: number,
    firstUsedMonth: string,
    taxYear: number
  ): Form2290Data {
    let taxAmount = 0;

    if (grossWeight >= 55000 && grossWeight <= 75000) {
      taxAmount = 100 + ((grossWeight - 55000) / 1000) * 22;
    } else if (grossWeight > 75000) {
      taxAmount = 550;
    }

    const months = 12 - this.getMonthNumber(firstUsedMonth) + 1;
    if (months < 12) {
      taxAmount = (taxAmount / 12) * months;
    }

    return {
      year: taxYear,
      vin,
      grossWeight,
      firstUsedMonth,
      taxAmount,
      status: 'pending',
    };
  }

  calculateQuarterlyTaxEstimate(
    revenue: number,
    expenses: number,
    quarter: string,
    year: number
  ): TaxEstimate {
    const netIncome = revenue - expenses;
    const selfEmploymentTax = netIncome * 0.9235 * 0.153;
    const adjustedIncome = netIncome - selfEmploymentTax * 0.5;
    const standardDeductionQuarterly = 14600 / 4;
    const taxableIncome = Math.max(0, adjustedIncome - standardDeductionQuarterly);
    const incomeTax = taxableIncome * 0.22;

    return {
      quarter,
      year,
      estimatedIncome: revenue,
      estimatedExpenses: expenses,
      selfEmploymentTax,
      incomeTax,
      totalDue: selfEmploymentTax + incomeTax,
    };
  }

  generate1099Data(
    year: number,
    contractors: Array<{ name: string; ssn: string; totalPaid: number }>,
    companyInfo: { name: string; ein: string }
  ): Form1099Data[] {
    return contractors
      .filter((c) => c.totalPaid >= 600)
      .map((c) => ({
        year,
        payerName: companyInfo.name,
        payerEIN: companyInfo.ein,
        recipientName: c.name,
        recipientSSN: c.ssn,
        nonemployeeCompensation: c.totalPaid,
      }));
  }

  private getMonthNumber(month: string): number {
    const months: Record<string, number> = {
      january: 1, february: 2, march: 3, april: 4, may: 5, june: 6,
      july: 7, august: 8, september: 9, october: 10, november: 11, december: 12,
    };
    return months[month.toLowerCase()] || 1;
  }
}

export const taxService = new TaxService();
