// TypeScript
// supabase/functions/hazards-ingest/index.ts
// Deploy: supabase functions deploy hazards-ingest --no-verify-jwt
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

/**
 * POST /hazards-ingest
 * Body: { items: Array<{type, severity, status?, lat,lng,title?,description?,road?,mm_ref?, detected_at?, fleet_id?, vehicle_id?, extra?}> }
 */
Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }
    const json = await req.json().catch(() => ({}));
    const items = Array.isArray(json?.items) ? json.items : [];
    if (!items.length) {
      return new Response(JSON.stringify({ ok: true, ingested: 0 }), { status: 200 });
    }

    const rows = items.map((it: any) => ({
      type: it.type,
      severity: it.severity ?? "medium",
      status: it.status ?? "active",
      title: it.title ?? null,
      description: it.description ?? null,
      source: it.source ?? "ingest",
      lat: Number(it.lat),
      lng: Number(it.lng),
      road: it.road ?? null,
      mm_ref: it.mm_ref ?? null,
      detected_at: it.detected_at ? new Date(it.detected_at).toISOString() : new Date().toISOString(),
      fleet_id: it.fleet_id ?? null,
      vehicle_id: it.vehicle_id ?? null,
      extra: it.extra ?? {},
    }));

    const { data, error } = await supabase.from("hazards").insert(rows).select("id");
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true, ingested: data?.length ?? 0 }), { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
