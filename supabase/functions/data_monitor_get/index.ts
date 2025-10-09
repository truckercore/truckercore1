// Supabase Edge Function: data_monitor_get
// Path: supabase/functions/data_monitor_get/index.ts
// GET /functions/v1/data_monitor_get?org_id=... (optional)
// Returns health for prioritized data feeds and anomaly counts, with simple SLA flags.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function minutesSince(iso?: string | null) {
  if (!iso) return null;
  const d = new Date(iso).getTime();
  if (!Number.isFinite(d)) return null;
  return Math.round((Date.now() - d) / 60000);
}

serve(async (req) => {
  try {
    const u = new URL(req.url);
    const org_id = u.searchParams.get("org_id");
    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Health from view
    const hv = await supa.from("data_feed_health").select("feed,last_hour_count,latest_event_at,latest_received_at");
    if (hv.error) throw hv.error;

    // Anomaly counts (last 1h)
    const an = await supa
      .from("data_anomalies")
      .select("feed, count:id", { head: false, count: "exact" })
      .gte("created_at", new Date(Date.now() - 3600_000).toISOString());
    // supabase-js can't group with count easily without RPC; perform two queries per feed instead

    const feeds = ["telemetry", "facility_dwell", "broker_behavior"];
    const data: any[] = [];
    for (const f of feeds) {
      const row = hv.data?.find((r: any) => r.feed === f);
      let latest_event_at = row?.latest_event_at ?? null;
      let latest_received_at = row?.latest_received_at ?? null;
      if (org_id) {
        // Narrow per org by checking tables directly
        let latest: any = null;
        if (f === "telemetry") {
          const r = await supa
            .from("telemetry_events")
            .select("event_at,received_at", { count: "exact" })
            .eq("org_id", org_id)
            .order("event_at", { ascending: false })
            .limit(1);
          latest = r.data?.[0];
        } else if (f === "facility_dwell") {
          const r = await supa
            .from("facility_dwell_events")
            .select("event_at,received_at", { count: "exact" })
            .eq("org_id", org_id)
            .order("event_at", { ascending: false })
            .limit(1);
          latest = r.data?.[0];
        } else if (f === "broker_behavior") {
          const r = await supa
            .from("broker_behavior_events")
            .select("event_at,received_at", { count: "exact" })
            .eq("org_id", org_id)
            .order("event_at", { ascending: false })
            .limit(1);
          latest = r.data?.[0];
        }
        latest_event_at = latest?.event_at ?? latest_event_at;
        latest_received_at = latest?.received_at ?? latest_received_at;
      }

      // Compute simple SLA flags
      const recMin = minutesSince(latest_received_at);
      let status = "ok";
      if (f === "telemetry") {
        if (recMin == null || recMin > 5) status = "degraded";
        if (recMin != null && recMin > 15) status = "down";
      } else if (f === "facility_dwell") {
        if (recMin == null || recMin > 15) status = "degraded";
        if (recMin != null && recMin > 60) status = "down";
      } else if (f === "broker_behavior") {
        if (recMin == null || recMin > 60) status = "degraded";
        if (recMin != null && recMin > 240) status = "down";
      }

      // Anomalies last 1h for this feed
      const anCount = await supa
        .from("data_anomalies")
        .select("id", { count: "exact", head: true })
        .eq("feed", f)
        .gte("created_at", new Date(Date.now() - 3600_000).toISOString());

      data.push({
        feed: f,
        latest_event_at,
        latest_received_at,
        minutes_since_received: recMin,
        last_hour_count: row?.last_hour_count ?? null,
        anomalies_last_hour: anCount.count ?? 0,
        status,
      });
    }

    return new Response(JSON.stringify({ ok: true, data }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
