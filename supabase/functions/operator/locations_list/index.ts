// Supabase Edge Function: operator/locations_list
// GET /functions/v1/operator/locations_list?scope=mine
// Returns locations within caller's scope (org + optional location_access), with quick filters.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}

serve(async (req) => {
  try {
    if (req.method !== "GET") return new Response("Method not allowed", { status: 405 });
    const auth = req.headers.get("Authorization") ?? "";
    const supa = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });

    const { data: u } = await supa.auth.getUser();
    if (!u?.user) return new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), { status: 401, headers: { "content-type": "application/json" } });

    const qs = new URL(req.url).searchParams;
    const scope = (qs.get("scope") ?? "mine").toString();
    const status = qs.get("status"); // parking|promos|alerts etc. (MVP: parking)

    // Resolve org_id and location access via profile + RLS-enforced views
    const { data: prof, error: perr } = await supa.from("profiles").select("org_id").eq("user_id", u.user.id).single();
    if (perr) return new Response(JSON.stringify({ error: "PROFILE_LOOKUP_FAILED" }), { status: 400, headers: { "content-type": "application/json" } });
    const org_id = (prof as any)?.org_id;

    // Base query: v_location_latest view narrowed by org via RLS
    let q = supa.from("v_location_latest").select("location_id,org_id,name,lat,lng,parking_status,available_spots,diesel_effective_cents,score");

    // Optional quick filter example
    if (status === "parking") {
      q = q.in("parking_status", ["open", "limited"] as any);
    }

    const { data, error } = await q;
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "content-type": "application/json" } });

    return new Response(JSON.stringify({ ok: true, org_id, locations: data ?? [] }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
