import { serve } from "std/server";
import { supabase } from "../lib/supabase_client.ts";
import { makeRequestId, ok, badRequest, error as errResp } from "../lib/http.ts";

// Community Review Submission
// Deploy: supabase functions deploy review-submit --no-verify-jwt
// Invoke: supabase functions invoke review-submit -b '{"driver_id":"uuid","poi_id":"uuid","review":{"overall":5,"comment":"Clean showers"}}'

serve(async (req) => {
  const request_id = makeRequestId(req);
  try {
    const { driver_id, poi_id, review } = await req.json();
    if (!driver_id || !poi_id || !review) {
      return badRequest("driver_id, poi_id, and review required", request_id);
    }

    const row = {
      driver_id,
      poi_id,
      cleanliness: review.cleanliness ?? null,
      comfort: review.comfort ?? null,
      parking: review.parking ?? null,
      food: review.food ?? null,
      safety: review.safety ?? null,
      overall: review.overall ?? null,
      comment: review.comment ?? null,
      photo_url: review.photo_url ?? null,
    };

    const { error } = await supabase.from("driver_reviews").insert(row);
    if (error) throw error;

    return ok({ ok: true }, request_id);
  } catch (err) {
    console.error("review_submit error", request_id, err);
    return errResp(String(err), request_id, 500);
  }
});
