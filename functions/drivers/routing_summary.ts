import { serve } from "std/server";
import { generateTruckSafeRoute } from "../lib/routing_ai.ts";
import { supabase } from "../lib/supabase_client.ts";
import { makeRequestId, ok, badRequest, error as errResp } from "../lib/http.ts";
import { metricsPush } from "../lib/metrics.ts";

// Truck-Safe Route Summary (AI+GIS backend stub)
// Deploy: supabase functions deploy routing-summary --no-verify-jwt
// Invoke: supabase functions invoke routing-summary -b '{"driver_id":"uuid","vehicle_specs":{},"origin":{"lat":41.88,"lng":-87.63},"destination":{"lat":34.05,"lng":-118.24},"hazmat":false}'

serve(async (req) => {
  const request_id = makeRequestId(req);
  const started = Date.now();
  try {
    const { driver_id, vehicle_specs, origin, destination, hazmat } = await req.json();

    if (!origin || !destination) {
      await metricsPush('routing-summary', 'bad_request', { reason: 'missing_origin_or_destination' }, request_id, 1.0);
      return badRequest("origin and destination required", request_id);
    }

    // Premium gate: require drivers.is_premium for route summary (slice A)
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

    const summary = await generateTruckSafeRoute(origin, destination, vehicle_specs ?? {}, !!hazmat);
    const latency_ms = Date.now() - started;
    await metricsPush('routing-summary', 'ok', { latency_ms }, request_id, 0.25);
    return ok({ driver_id, summary }, request_id);
  } catch (err) {
    console.error("routing_summary error", request_id, err);
    await metricsPush('routing-summary', 'error', { message: String(err) }, request_id, 1.0);
    return errResp(String(err), request_id, 500);
  }
});
