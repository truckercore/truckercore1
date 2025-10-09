// deno-fns/roi_log.ts
// Log ROI events into ai_roi_events with normalization helpers
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type RoiEventType = 'promo_redeemed' | 'fuel_saved' | 'hos_violation_avoided';

interface RoiLogRequest {
  org_id: string;
  driver_user_id?: string | null;
  event_type: RoiEventType;
  // If amount_usd missing, compute from provided fields below
  amount_usd?: number;
  // Optional raw inputs for normalization
  gallons_saved?: number;                 // e.g., 12.5
  fuel_price_usd_per_gal?: number;       // e.g., 3.85
  promo_incremental_revenue_usd?: number;// computed uplift
  hos_violation_cost_usd?: number;       // e.g., 150.0 per avoided violation
  baseline?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
  occurred_at?: string;                  // ISO
}

const url = Deno.env.get("SUPABASE_URL")!;
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // align with env.example
const db = createClient(url, service, { auth: { persistSession: false }});

function bad(status: number, msg: string) {
  return new Response(JSON.stringify({ error: msg }), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return bad(405, "method_not_allowed");
  let body: RoiLogRequest;
  try { body = await req.json(); } catch { return bad(400, "invalid_json"); }

  const { org_id, event_type } = body;
  if (!org_id || !event_type) return bad(400, "missing_required");
  if (!['promo_redeemed','fuel_saved','hos_violation_avoided'].includes(event_type)) return bad(422, "invalid_event_type");

  // Normalize amount
  let amount = body.amount_usd ?? 0;
  const baseline: Record<string, unknown> = body.baseline ?? {};
  const metadata: Record<string, unknown> = body.metadata ?? {};

  if (body.amount_usd == null) {
    if (event_type === 'fuel_saved') {
      const gals = Number(body.gallons_saved ?? 0);
      const price = Number(body.fuel_price_usd_per_gal ?? baseline['fuel_price_usd_per_gal'] ?? 0);
      amount = Math.max(0, +(gals * price).toFixed(2));
      baseline['fuel_price_usd_per_gal'] = price;
      metadata['gallons_saved'] = gals;
    } else if (event_type === 'promo_redeemed') {
      const uplift = Number(body.promo_incremental_revenue_usd ?? 0);
      amount = Math.max(0, +uplift.toFixed(2));
    } else if (event_type === 'hos_violation_avoided') {
      const cost = Number(body.hos_violation_cost_usd ?? baseline['hos_violation_cost_usd'] ?? 0);
      amount = Math.max(0, +cost.toFixed(2));
      if (baseline['hos_violation_rate'] === undefined) baseline['hos_violation_rate'] = null;
      baseline['hos_violation_cost_usd'] = cost;
    }
  }

  if (!(amount >= 0)) return bad(422, "invalid_amount");

  // Insert
  const { error } = await db.from("ai_roi_events").insert({
    org_id,
    driver_user_id: body.driver_user_id ?? null,
    event_type,
    amount_usd: amount,
    baseline,
    metadata,
    occurred_at: body.occurred_at ?? new Date().toISOString()
  });
  if (error) return bad(500, error.message);

  return new Response(JSON.stringify({ ok: true, amount_usd: amount }), { headers: { "content-type": "application/json" } });
});
