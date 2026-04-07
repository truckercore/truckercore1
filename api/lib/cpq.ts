// api/lib/cpq.ts
// CPQ calculator and approval guard
export type Band = { name: string; price_per_location_usd: number }
export type TierDisc = { min: number; max: number | null; discount_pct: number }
export type Prepay = { term_months: number; discount_pct: number }
export type Rules = { bands: Band[]; multi_location_discounts: TierDisc[]; prepay_discounts: Prepay[]; max_sales_override_pct: number; requires_approval_above_pct: number }

export function priceForBand(rules: Rules, bandName: string, locations: number) {
  const band = rules.bands.find(b => b.name.toLowerCase() === bandName.toLowerCase())
  if (!band) throw new Error('band_not_found')
  const list = band.price_per_location_usd * locations

  let tierDisc = 0
  for (const t of rules.multi_location_discounts) {
    const within = locations >= t.min && (t.max == null || locations <= t.max)
    if (within) { tierDisc = Math.max(tierDisc, t.discount_pct) }
  }
  return { list_usd: list, tier_discount_pct: tierDisc }
}

export function applyPrepay(listAfterTier: number, rules: Rules, termMonths: number) {
  const pre = rules.prepay_discounts.find(p => p.term_months === termMonths)
  return pre ? Math.round(listAfterTier * (1 - pre.discount_pct / 100)) : Math.round(listAfterTier)
}

export function guardApproval(requestedDiscountPct: number, rules: Rules) {
  if (requestedDiscountPct > rules.max_sales_override_pct) throw new Error('discount_exceeds_policy')
  return { requiresApproval: requestedDiscountPct > rules.requires_approval_above_pct }
}
