import { serve } from "std/server";
import { getLatestReviews } from "../lib/db.ts";
import { makeRequestId, ok, badRequest, error as errResp } from "../lib/http.ts";

// Feedback Aggregation for dashboards/alerts with pagination
// Deploy: supabase functions deploy feedback-aggregation --no-verify-jwt
// Invoke: supabase functions invoke feedback-aggregation -b '{"truck_stop_id":"uuid"}'

serve(async (req) => {
  const request_id = makeRequestId(req);
  try {
    const body = await req.json();
    const truck_stop_id: string | undefined = body.truck_stop_id;
    let limit: number = Number(body.limit ?? 50);
    const cursor: string | undefined = body.cursor ?? undefined; // ISO timestamp of last seen created_at
    if (!truck_stop_id) {
      return badRequest("Missing truck_stop_id", request_id);
    }
    if (!Number.isFinite(limit) || limit <= 0) limit = 50;
    if (limit > 200) limit = 200;

    // Basic pagination: we don't have a DB function for cursor here; reuse helper and slice in code when cursor provided
    const batch = await getLatestReviews(truck_stop_id, 200);
    let filtered = batch;
    if (cursor) {
      const c = Date.parse(cursor);
      if (!Number.isNaN(c)) {
        filtered = batch.filter((r: any) => Date.parse(r.created_at) < c);
      }
    }
    const items = filtered.slice(0, limit);
    const overall = items.length ? items.reduce((sum: number, r: any) => sum + (r.overall ?? 0), 0) / items.length : 0;
    const next_cursor = items.length === filtered.length ? null : (items.at(-1)?.created_at ?? null);

    return ok({ latest: items, overall }, request_id, undefined, next_cursor ?? undefined);
  } catch (err) {
    console.error("feedback_aggregation error", request_id, err);
    return errResp(String(err), request_id, 500);
  }
});
