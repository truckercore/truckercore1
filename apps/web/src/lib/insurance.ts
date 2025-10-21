export type InsuranceQuote = {
  provider: string;
  premium_monthly: number;
  coverage_limit: number;
  deductible: number;
  quote_id: string;
};

export async function getInsuranceQuote(orgId: string, fleetSize: number): Promise<InsuranceQuote> {
  const NEXT_INSURANCE_API_KEY = process.env.NEXT_INSURANCE_API_KEY;
  if (!NEXT_INSURANCE_API_KEY) {
    return {
      provider: "Next Insurance (Demo)",
      premium_monthly: fleetSize * 350 + Math.floor(Math.random() * 200),
      coverage_limit: 1000000,
      deductible: 2500,
      quote_id: `demo-${Date.now()}`,
    };
  }
  // Real implementation would call provider API
  return {
    provider: "Next Insurance",
    premium_monthly: fleetSize * 350,
    coverage_limit: 1000000,
    deductible: 2500,
    quote_id: "real-quote-id",
  };
}
