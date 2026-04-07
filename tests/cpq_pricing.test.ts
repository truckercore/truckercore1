// tests/cpq_pricing.test.ts
import { strict as assert } from "node:assert";

type QuoteInput = {
  locations: number;
  band: "199" | "349" | "499";
  prepay: "monthly" | "quarterly" | "annual";
  overridePct?: number; // negative for discount, positive for uplift
};

const BANDS = { "199": 19900, "349": 34900, "499": 49900 } as const; // cents
const MULTI_DISCOUNT = (n: number) => (n >= 250 ? 0.18 : n >= 50 ? 0.10 : n >= 10 ? 0.05 : 0);
const PREPAY_DISCOUNT = { monthly: 0, quarterly: 0.03, annual: 0.08 } as const;
const MAX_OVERRIDE_ABS = 0.30; // 30% cap absolute

function pricePerLocationCents(q: QuoteInput) {
  const base = BANDS[q.band];
  const multi = MULTI_DISCOUNT(q.locations);
  const prepay = PREPAY_DISCOUNT[q.prepay] ?? 0;
  const override = Math.max(-MAX_OVERRIDE_ABS, Math.min(MAX_OVERRIDE_ABS, q.overridePct ?? 0));
  const stacked = 1 - multi;           // multi-location first
  const afterPrepay = stacked * (1 - prepay); // then prepay
  const afterOverride = afterPrepay * (1 + override); // override last, enforced
  return Math.round(base * afterOverride);
}

describe("CPQ pricing", () => {
  it("applies tier boundaries correctly", () => {
    // 9 → no discount, 10 → 5%
    const p9 = pricePerLocationCents({ locations: 9, band: "199", prepay: "monthly" });
    const p10 = pricePerLocationCents({ locations: 10, band: "199", prepay: "monthly" });
    assert.equal(p9, 19900);
    assert.equal(p10, Math.round(19900 * 0.95));
    // 49 vs 50 (10%), 249 vs 250 (18%)
    const p49 = pricePerLocationCents({ locations: 49, band: "349", prepay: "monthly" });
    const p50 = pricePerLocationCents({ locations: 50, band: "349", prepay: "monthly" });
    assert.equal(p49, 34900);
    assert.equal(p50, Math.round(34900 * 0.90));
    const p249 = pricePerLocationCents({ locations: 249, band: "499", prepay: "monthly" });
    const p250 = pricePerLocationCents({ locations: 250, band: "499", prepay: "monthly" });
    assert.equal(p249, 49900 * 0.90); // still at 10%
    assert.equal(p250, Math.round(49900 * 0.82));
  });

  it("enforces max override ±30%", () => {
    const up = pricePerLocationCents({ locations: 5, band: "199", prepay: "monthly", overridePct: 0.5 });
    const dn = pricePerLocationCents({ locations: 5, band: "199", prepay: "monthly", overridePct: -0.5 });
    assert.equal(up, Math.round(19900 * 1.30));
    assert.equal(dn, Math.round(19900 * 0.70));
  });

  it("stacks prepay after multi-location discount", () => {
    const base = 34900;
    const expect = Math.round(base * 0.90 * 0.92); // 10% multi, 8% annual
    const got = pricePerLocationCents({ locations: 50, band: "349", prepay: "annual" });
    assert.equal(got, expect);
  });
});
