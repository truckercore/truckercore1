import { serve } from "std/server";
import { getMarketplaceLoads, getCurrentLocation, supabaseAdmin } from "../lib/db.ts";
import { roadDoggAiSuggestBestLoad } from "../lib/roadDoggAi.ts";
import { makeRequestId, ok, badRequest, error as errResp } from "../lib/http.ts";

// Smart Load Matching & Deadhead Calculation
// Deploy: supabase functions deploy smart-load-match --no-verify-jwt
// Invoke: supabase functions invoke smart-load-match -b '{"owner_op_id":"uuid","equipment_type":"reefer","location_lat":41.88,"location_lng":-87.63,"max_radius_miles":150}'

serve(async (req) => {
  const started = Date.now();
  const request_id = makeRequestId(req);
  try {
    const body = await req.json();
    const owner_op_id: string = body.owner_op_id;
    const equipment_type: string | undefined = body.equipment_type;
    const location_lat: number | undefined = body.location_lat;
    const location_lng: number | undefined = body.location_lng;
    let max_radius_miles: number = body.max_radius_miles ?? 100;

    // Input validation
    if (!owner_op_id) {
      return badRequest("owner_op_id required", request_id);
    }
    if (typeof max_radius_miles !== "number" || !isFinite(max_radius_miles) || max_radius_miles <= 0) {
      max_radius_miles = 100;
    }
    if (max_radius_miles > 300) max_radius_miles = 300; // cap radius to avoid heavy scans
    if (location_lat !== undefined && (location_lat < -90 || location_lat > 90)) {
      return badRequest("location_lat out of bounds", request_id);
    }
    if (location_lng !== undefined && (location_lng < -180 || location_lng > 180)) {
      return badRequest("location_lng out of bounds", request_id);
    }

    let origin: { lat: number; lng: number };
    if (typeof location_lat === "number" && typeof location_lng === "number") {
      origin = { lat: location_lat, lng: location_lng };
    } else {
      // fallback to last known location from DB
      const loc = await getCurrentLocation(owner_op_id);
      origin = loc ?? { lat: 39.0997, lng: -94.5786 }; // default to Kansas City
    }

    // Fetch with paging defaults (db-side should support limit/cursor if available)
    const loads = await getMarketplaceLoads({
      equipment_type,
      center: origin,
      radius: max_radius_miles,
      limit: 200,
    });

    const suggestion = await roadDoggAiSuggestBestLoad(owner_op_id, loads, origin);

    // Observability/audit (best-effort)
    const latency_ms = Date.now() - started;
    try {
      await supabaseAdmin.from("audit_log").insert({
        table_name: "edge.smart_load_match",
        record_id: null,
        action: "suggest",
        edited_by: null,
        old_values: null,
        new_values: { owner_op_id, loads_considered: Array.isArray(loads) ? loads.length : 0, best_load: suggestion?.best_load?.id ?? null, latency_ms, request_id },
      });
    } catch (e) {
      console.warn("audit insert failed", e);
    }

    return ok({ suggestion, latency_ms }, request_id);
  } catch (err) {
    console.error("smart_load_match error", request_id, err);
    return errResp(String(err), request_id, 500);
  }
});
