import { serve } from "std/server";
import { findCheapestFunnelsAlongRoute } from "../lib/fuel_optim.ts";
import { supabase } from "../lib/supabase_client.ts";
import { makeRequestId, ok, badRequest, error as errResp } from "../lib/http.ts";

// Fuel Price Optimization (AI Suggestion stub)
// Deploy: supabase functions deploy fuel-optimization --no-verify-jwt
// Invoke: supabase functions invoke fuel-optimization -b '{"route_gpx":{},"fuel_type":"diesel"}'

serve(async (req) => {
  const request_id = makeRequestId(req);
  try {
    const { route_gpx, fuel_type, driver_id } = await req.json();
    if (!route_gpx) {
      return badRequest("route_gpx required", request_id);
    }

    // Premium gate: require drivers.is_premium
    if (driver_id) {
      const { data: drv, error } = await supabase.from("drivers").select("is_premium").eq("id", driver_id).single();
      if (error) {
        console.warn("drivers lookup error", error);
      }
      const premium = drv?.is_premium === true;
      if (!premium) {
        return new Response(
          JSON.stringify({ ok: false, error: { code: 'payment_required', message: 'Premium required' }, request_id, upgrade_url: "https://truckercore.app/upgrade" }),
          { headers: { "Content-Type": "application/json", "x-request-id": request_id }, status: 402 },
        );
      }
    }

    const suggestion = await findCheapestFunnelsAlongRoute(route_gpx, fuel_type ?? "diesel");
    return ok({ suggestion }, request_id);
  } catch (err) {
    console.error("fuel_optimization error", request_id, err);
    return errResp(String(err), request_id, 500);
  }
});
