// functions/ai_drift_check/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const PSI_THRESHOLD = Number(Deno.env.get("AI_PSI_THRESHOLD") ?? 0.2);

function psi(trainDist: number[], liveDist: number[]) {
  let s = 0;
  for (let i = 0; i < Math.min(trainDist.length, liveDist.length); i++) {
    const e = trainDist[i] || 1e-6;
    const a = liveDist[i] || 1e-6;
    s += (a - e) * Math.log(a / e);
  }
  return s;
}

Deno.serve(async (_req) => {
  const db = createClient(URL, KEY, { auth: { persistSession: false } });
  // Latest summaries per module (take newest row per module)
  const { data: feats } = await db.from("ai_feature_summaries").select("module, summary, created_at").order("created_at", { ascending: false });
  const latestByModule = new Map<string, any>();
  for (const r of feats ?? []) if (!latestByModule.has(r.module)) latestByModule.set(r.module, r);

  for (const [module, rec] of latestByModule.entries()) {
    const summary = (rec as any).summary as Record<string, any>;
    const since = new Date(Date.now() - 7*24*3600*1000).toISOString();
    const { data: pred } = await db
      .from("ai_predictions")
      .select("features")
      .eq("module", module)
      .gte("created_at", since)
      .limit(5000);
    if (!pred || pred.length === 0) continue;

    for (const [feature, conf] of Object.entries(summary)) {
      const bins: number[] = (conf as any).bins || [];
      const trainDist: number[] = (conf as any).dist || [];
      if (!bins.length || !trainDist.length) continue;

      const counts = new Array(trainDist.length).fill(0);
      for (const row of pred) {
        const v = (row as any).features?.[feature];
        if (typeof v !== "number") continue;
        let idx = trainDist.length - 1;
        for (let b = 0; b < bins.length; b++) { if (v < bins[b]) { idx = b; break; } }
        counts[idx] += 1;
      }
      const total = counts.reduce((a,b)=>a+b,0) || 1;
      const liveDist = counts.map(c => c / total);
      const vpsi = psi(trainDist, liveDist);
      await db.from("ai_drift").insert({ module, feature, psi: vpsi, train_snapshot: conf, live_snapshot: { bins, dist: liveDist } }, { returning: "minimal" });
      // Threshold exceeded handling left to alerting pipeline
      if (vpsi > PSI_THRESHOLD) {
        // no-op here; downstream alerts can query ai_drift
      }
    }
  }
  return new Response("ok");
});
