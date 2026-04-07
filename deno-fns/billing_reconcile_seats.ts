// deno-fns/billing_reconcile_seats.ts
// Seat reconciliation job: flags drift > 1 between subscription quantity and billable location seats
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@16?target=deno";

const s = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
// Stripe client present for potential future adjustments (not used directly here)
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const stripe = new Stripe(Deno.env.get("STRIPE_SECRET")!, { apiVersion: "2024-06-20" });

Deno.serve(async () => {
  try {
    // 1) Get orgs with active subs
    const { data: subs, error } = await s
      .from("org_subscriptions")
      .select("org_id,id,price_id,quantity,status")
      .in("status", ["trialing","active"]);
    if (error) return new Response(error.message, { status: 500 });

    // 2) Fetch seats view
    const { data: seats, error: errSeats } = await s.from("v_org_location_seats").select("org_id,seats");
    if (errSeats) return new Response(errSeats.message, { status: 500 });

    const seatMap = new Map((seats ?? []).map((r: any) => [r.org_id, r.seats]));

    // Ensure alerts_events exists before inserting (best-effort)
    const canAlert = await s
      .from("alerts_events")
      .select("count(*)", { head: true, count: "estimated" })
      .then(() => true)
      .catch(() => false);

    let driftCount = 0;
    for (const sub of subs ?? []) {
      const orgSeats = seatMap.get(sub.org_id) ?? 0;
      const q = (sub.quantity ?? 0) as number;
      const drift = Math.abs(q - orgSeats);
      if (drift > 1 && canAlert) {
        driftCount++;
        await s.from("alerts_events").insert({
          org_id: sub.org_id,
          severity: "warning",
          code: "BILLING_SEAT_DRIFT",
          payload: { subscription_id: sub.id, price_id: sub.price_id, quantity: q, seats: orgSeats, drift }
        });
      }
    }
    return new Response(JSON.stringify({ status: "ok", driftCount }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response((e as Error).message, { status: 500 });
  }
});
