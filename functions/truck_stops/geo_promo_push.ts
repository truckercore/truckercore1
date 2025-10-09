import { serve } from "std/server";
import { getNearbyDrivers, sendPromotionNotification, supabaseAdmin } from "../lib/db.ts";
import { makeRequestId, ok, badRequest, error as errResp } from "../lib/http.ts";
import { auditInsert } from "../lib/audit.ts";

// Geo-Targeted Promotions Push
// Deploy: supabase functions deploy geo-promo-push --no-verify-jwt
// Invoke: supabase functions invoke geo-promo-push -b '{"promo_id":"uuid","truck_stop_id":"uuid"}'

serve(async (req) => {
  const request_id = makeRequestId(req);
  const started = Date.now();
  try {
    const { promo_id, truck_stop_id } = await req.json();
    if (!promo_id || !truck_stop_id) {
      return badRequest("Missing promo_id or truck_stop_id", request_id);
    }

    const { data: promo, error: promoErr } = await supabaseAdmin
      .from("promotions").select("id, truck_stop_id, is_active, geo_radius").eq("id", promo_id).single();
    if (promoErr) throw promoErr;
    if (!promo?.is_active) return ok({ notified: 0, reason: "promo_inactive" }, request_id);

    const radius = promo.geo_radius ?? 50;
    const drivers = await getNearbyDrivers(truck_stop_id, radius);

    for (const d of drivers) {
      await sendPromotionNotification(d.id, promo_id);
    }
    const latency_ms = Date.now() - started;
    await auditInsert("edge.geo_promo_push", "notify", { promo_id, truck_stop_id, notified: drivers.length, latency_ms }, request_id, 0.25);
    return ok({ notified: drivers.length, latency_ms }, request_id);
  } catch (err) {
    console.error("geo_promo_push error", request_id, err);
    return errResp(String(err), request_id, 500);
  }
});
