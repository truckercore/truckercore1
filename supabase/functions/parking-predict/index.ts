// supabase/functions/parking-predict/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
type PredictReq = { org_id: string; location_id: string; horizons?: number[] };

export const handler = async (req: Request) => {
  try {
    const body = (await req.json()) as PredictReq;
    const horizons = body.horizons?.length ? body.horizons : [0, 15, 30, 60];
    const { createClient } = await import("npm:@supabase/supabase-js");
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const since = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString();
    const [{ data: crowd }, { data: oper }] = await Promise.all([
      sb.from("parking_status_reports").select("available_estimate, observed_at").eq("location_id", body.location_id).gte("observed_at", since).order("observed_at", { ascending: false }).limit(200),
      sb.from("parking_operator_status").select("available, observed_at").eq("location_id", body.location_id).gte("observed_at", since).order("observed_at", { ascending: false }).limit(60),
    ]);
    const latestOper = oper?.[0]?.available ?? null;
    const latestCrowd = crowd?.[0]?.available_estimate ?? null;
    const nowEstimate = latestOper ?? latestCrowd ?? null;
    const predictions = horizons.map((h) => ({
      org_id: body.org_id,
      location_id: body.location_id,
      horizon_minutes: h,
      predicted_for: new Date(Date.now() + h * 60 * 1000).toISOString(),
      predicted_free: nowEstimate,
      model: "parking_v1",
      model_version: "baseline-0.1",
      features: { has_operator: latestOper !== null, has_crowd: latestCrowd !== null },
    }));
    const { error } = await sb.from("parking_predictions").upsert(predictions as any, { onConflict: "org_id,location_id,predicted_for,model" });
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true, inserted: predictions.length }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
};
Deno.serve(handler);
