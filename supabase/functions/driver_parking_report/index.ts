// Supabase Edge Function: driver_parking_report
// Path: supabase/functions/driver_parking_report/index.ts
// Invoke: POST /functions/v1/driver_parking_report { location_id, status?|available_spots?, capacity?, device_hash? }
// Behavior: inserts a crowd-sourced parking_status row and returns ok with next_recompute hint

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!SUPABASE_ANON) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response(JSON.stringify({ error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });

    const auth = req.headers.get("Authorization") ?? "";
    const user = createClient(SUPABASE_URL, SUPABASE_ANON, { global: { headers: { Authorization: auth } } });

    // Optional auth: prefer authenticated so we can stamp updated_by
    const { data: ures } = await user.auth.getUser();
    const actor = ures?.user ?? null;

    const body = await req.json().catch(() => ({} as any));
    const location_id = String(body.location_id || "").trim();
    const status = body.status as "open" | "limited" | "full" | "unknown" | undefined;
    const available_spots = typeof body.available_spots === "number" ? body.available_spots : undefined;
    const capacity = typeof body.capacity === "number" ? body.capacity : undefined;

    if (!location_id) return new Response(JSON.stringify({ error: "MISSING_LOCATION_ID" }), { status: 400, headers: { "content-type": "application/json" } });

    const row: Record<string, unknown> = {
      location_id,
      source: "crowd",
      updated_at: new Date().toISOString(),
    };
    if (status) row.status = status;
    if (available_spots != null) row.available_spots = available_spots;
    if (capacity != null) row.capacity = capacity;
    if (actor?.id) row.updated_by = actor.id;

    const { error } = await user.from("parking_status").insert(row as any);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { "content-type": "application/json" } });

    // Hints for client: next recompute within a couple of minutes
    return new Response(JSON.stringify({ ok: true, next_recompute_s: 120 }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
