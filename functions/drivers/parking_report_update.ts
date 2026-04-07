import { serve } from "std/server";
import { supabase } from "../lib/supabase_client.ts";
import { makeRequestId, ok, badRequest, error as errResp } from "../lib/http.ts";

// Parking Report Update (crowd-sourced)
// Deploy: supabase functions deploy parking-report-update --no-verify-jwt
// Invoke: supabase functions invoke parking-report-update -b '{"poi_id":"uuid","driver_id":"uuid","available_spots":12,"confidence":70,"is_premium":false}'

serve(async (req) => {
  const request_id = makeRequestId(req);
  try {
    const { poi_id, driver_id, available_spots, confidence, is_premium } = await req.json();
    if (!poi_id || !driver_id) {
      return badRequest("poi_id and driver_id required", request_id);
    }

    const { error } = await supabase.from("parking_reports").insert({
      poi_id,
      driver_id,
      available_spots,
      confidence,
      is_premium_report: !!is_premium,
    });

    if (error) throw error;

    return ok({ ok: true }, request_id);
  } catch (err) {
    console.error("parking_report_update error", request_id, err);
    return errResp(String(err), request_id, 500);
  }
});
