// Supabase Edge Function: Seed Loads Import (CSV)
// Path: supabase/functions/seed_loads_import/index.ts
// Invoke with: POST /functions/v1/seed_loads_import (Content-Type: text/csv)
// Accepts CSV headers: broker_name, origin_city, origin_state, dest_city, dest_state, pickup_start, pickup_end, equipment, rate_usd, distance_mi

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { parse as parseCsv } from "https://deno.land/std@0.224.0/csv/parse.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

    const contentType = req.headers.get("content-type") ?? "";
    if (!contentType.includes("text/csv") && !contentType.includes("multipart/form-data")) {
      return new Response("Unsupported media type", { status: 415 });
    }

    const text = await req.text();
    const rows = [...parseCsv(text, { columns: true, skipFirstRow: true })] as Record<string, string>[];

    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false }, global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );

    let inserted = 0;
    for (const r of rows) {
      const rate = r.rate_usd ? Number(r.rate_usd) : null;
      const distance = r.distance_mi ? Number(r.distance_mi) : null;
      const cpm = rate != null && distance != null && distance > 0 ? rate / distance : null;

      const ins = await sb.from("marketplace_demo_loads").insert({
        broker_name: r.broker_name ?? "Demo Broker",
        origin_city: r.origin_city,
        origin_state: r.origin_state,
        dest_city: r.dest_city,
        dest_state: r.dest_state,
        pickup_start: r.pickup_start ?? null,
        pickup_end: r.pickup_end ?? null,
        equipment: r.equipment ?? null,
        rate_usd: rate,
        cpm_est: cpm,
      });
      if (ins.error) throw ins.error;
      inserted++;
    }

    return new Response(JSON.stringify({ ok: true, inserted }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
