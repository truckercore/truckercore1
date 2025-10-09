// Path: supabase/functions/hos_ingest/index.ts
import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type HosPayload = {
  driver_id: string;
  start: string;   // ISO
  end: string;     // ISO
  status: "off_duty" | "sleeper" | "driving" | "on_duty";
  source?: "manual" | "native" | "eld_certified";
  eld_provider?: string | null;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const HOS_SNAP_GAP_MINUTES = Number(Deno.env.get("HOS_SNAP_GAP_MINUTES") ?? 5);

function minutesBetween(a: string, b: string) {
  return Math.abs((new Date(b).getTime() - new Date(a).getTime()) / 60000);
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Use POST", { status: 405 });
    const payload = (await req.json()) as HosPayload;
    if (!payload?.driver_id || !payload.start || !payload.end || !payload.status) {
      return new Response("Missing fields", { status: 400 });
    }
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    // Optional: validate overlap/gaps — simplistic example
    const { data: lastLogs } = await supabase
      .from("hos_logs")
      .select("start, end")
      .eq("driver_id", payload.driver_id)
      .order("end", { ascending: false })
      .limit(1);

    if (lastLogs?.length) {
      const lastEnd = lastLogs[0].end as string;
      const gap = minutesBetween(lastEnd, payload.start);
      if (gap > HOS_SNAP_GAP_MINUTES) {
        return new Response(JSON.stringify({ error: `Gap ${gap}m exceeds limit` }), { status: 400 });
      }
    }

    const { error: insErr } = await supabase.from("hos_logs").insert({
      driver_id: payload.driver_id,
      start: payload.start,
      end: payload.end,
      status: payload.status,
      source: payload.source ?? "manual",
      eld_provider: payload.eld_provider ?? null,
    });
    if (insErr) throw insErr;

    // Aggregate daily totals (simple example)
    const day = new Date(payload.start);
    day.setHours(0, 0, 0, 0);
    const dayStr = day.toISOString();

    const { data: dayLogs, error: dayErr } = await supabase
      .from("hos_logs")
      .select("start, end, status")
      .eq("driver_id", payload.driver_id)
      .gte("start", dayStr);
    if (dayErr) throw dayErr;

    const totals: Record<string, number> = {
      off_duty: 0, sleeper: 0, driving: 0, on_duty: 0,
    };
    for (const l of dayLogs ?? []) {
      const mins = minutesBetween(l.start, l.end);
      totals[l.status] += mins;
    }
    const hours = Object.fromEntries(Object.entries(totals).map(([k, v]) => [k, +(v / 60).toFixed(2)]));

    return new Response(JSON.stringify({ ok: true, day_hours: hours }), {
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});