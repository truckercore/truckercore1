import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async () => {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Prefer seasonal spikes; fallback to simple view
  let spikes = (await sb.from("v_ai_roi_spike_seasonal").select("*")).data ?? [];
  if (!spikes.length) spikes = (await sb.from("v_ai_roi_spike_alerts").select("*")).data ?? [];

  const count = spikes.length;
  console.log(JSON.stringify({ mod: "roi", ev: "spike_count", count, ts: new Date().toISOString() }));

  // Notify if configured
  const url = Deno.env.get("ALERT_WEBHOOK_URL");
  if (count > 0 && url) {
    await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ title: "ROI spike detected", count, items: spikes.slice(0, 10) }),
    }).catch(() => {});
  }

  return new Response(JSON.stringify({ spikes: count }), { headers: { "content-type": "application/json", "cache-control": "no-store" } });
});