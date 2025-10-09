// Supabase Edge Function: dwell_detector
// Scans recent vehicle_positions and maintains dwell_events, plus writes a heartbeat row.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

Deno.serve(async () => {
  const since = new Date(Date.now() - 20 * 60 * 1000).toISOString();

  const { data: pings, error } = await sb
    .from("vehicle_positions") // public schema (default)
    .select("vehicle_id, ts, lat, lng, speed_mph")
    .gte("ts", since)
    .order("vehicle_id", { ascending: true })
    .order("ts", { ascending: true });

  if (error) return new Response(error.message, { status: 500 });

  const byVeh: Record<string, any[]> = {};
  for (const row of (pings ?? [])) {
    (byVeh[row.vehicle_id] ||= []).push(row);
  }

  for (const [vehicle_id, arr] of Object.entries(byVeh)) {
    const cutoff = Date.now() - 10 * 60 * 1000;
    const recent = (arr as any[]).filter((r) => new Date((r as any).ts).getTime() >= cutoff);
    const avg = recent.length ? recent.reduce((s, r) => s + ((r as any).speed_mph ?? 0), 0) / recent.length : 999;

    const { data: current } = await sb
      .from("dwell_events")
      .select("*")
      .eq("vehicle_id", vehicle_id)
      .is("dwell_end", null)
      .limit(1)
      .maybeSingle();

    if (avg < 3) {
      if (!current) {
        const last = (arr as any[]).at(-1) ?? (recent as any[]).at(0);
        await sb.from("dwell_events").insert({
          vehicle_id,
          dwell_start: last?.ts ?? new Date().toISOString(),
          location: last ? { lat: last.lat, lng: last.lng } : null,
        });
      }
    } else if (current) {
      await sb.from("dwell_events").update({ dwell_end: new Date().toISOString() }).eq("id", (current as any).id);
    }
  }

  await sb.from("dwell_heartbeats").insert({});
  return new Response(JSON.stringify({ ok: true }), { status: 200 });
});
