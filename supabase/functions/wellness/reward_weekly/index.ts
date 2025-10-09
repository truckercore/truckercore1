// functions/wellness/reward_weekly/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async () => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  // Fetch all driver ids (adjust to your schema)
  const { data: drivers, error: derr } = await sb.from("drivers").select("user_id");
  if (derr) return new Response(JSON.stringify({ error: derr.message }), { status: 500, headers: { "content-type": "application/json" } });

  const since = new Date(Date.now() - 7 * 864e5).toISOString();
  let awarded = 0;
  for (const d of drivers ?? []) {
    const driverId = d.user_id;
    const { data: metrics, error: merr } = await sb
      .from("wellness_metrics")
      .select("value")
      .eq("driver_id", driverId)
      .eq("metric", "sleep_hours")
      .gte("recorded_at", since);
    if (merr) continue;

    const arr = (metrics ?? []).map((r: any) => Number(r.value) || 0);
    const avg = arr.length ? arr.reduce((s, v) => s + v, 0) / arr.length : 0;
    if (avg >= 7) {
      const { error: insErr } = await sb.from("wellness_rewards").insert({
        driver_id: driverId,
        reward_type: "points",
        points: 100,
        reason: "Healthy sleep"
      });
      if (!insErr) awarded += 1;
    }
  }
  return new Response(JSON.stringify({ ok: true, awarded }), { headers: { "content-type": "application/json" } });
});
