import { describe, it, expect } from 'vitest';
import { TaxService } from '../taxService';

const svc = new TaxService();

describe('TaxService', () => {
  it('generates IFTA report with totals', async () => {
    const report = await svc.generateIFTAReport(
      'Q3',
      2025,
      [
        { state: 'TX', miles: 500 },
        { state: 'OK', miles: 300 },
      ],
      [
        { state: 'TX', gallons: 50 },
        { state: 'OK', gallons: 20 },
      ]
    );

    expect(report.quarter).toBe('Q3');
    expect(report.year).toBe(2025);
    expect(report.stateBreakdown.length).toBeGreaterThan(0);
    expect(report.totalTax).toBeGreaterThanOrEqual(0);
  });

  it('calculates Form 2290 tax based on weight and month', () => {
    const form = svc.calculateForm2290('VIN123', 80000, 'July', 2025);
    expect(form.taxAmount).toBeGreaterThan(0);
    expect(form.status).toBe('pending');
  });

  it('estimates quarterly taxes', () => {
    const est = svc.calculateQuarterlyTaxEstimate(50000, 20000, 'Q3', 2025);
    expect(est.totalDue).toBeGreaterThan(0);
    expect(est.selfEmploymentTax).toBeGreaterThan(0);
  });
});
