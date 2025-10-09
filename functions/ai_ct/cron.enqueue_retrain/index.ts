import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
Deno.serve(async () => {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: drift } = await sb.from("ai_drift_snapshots")
    .select("stats->>'psi' psi").eq("model_key","eta").order("created_at",{ascending:false}).limit(1);
  const psi = drift?.[0]?.psi ? Number((drift as any)[0].psi) : 0;
  let labels2h = 0;
  try {
    const { data: count } = await sb.rpc("ai_eta_feedback_since", { minutes_back: 120 });
    labels2h = (count as any)?.count ?? 0;
  } catch {}
  const enough = labels2h >= 100 || psi > 0.25;
  if (enough) await sb.from("ai_training_jobs").insert({ model_key:"eta", job_kind:"retrain", params:{ window_hours:24, reason: psi>0.25?"drift":"labels" }});
  return new Response(JSON.stringify({ queued: enough, psi, labels_2h: labels2h }), { headers: { "content-type":"application/json" }});
});