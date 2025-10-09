// Supabase Edge Function: operator/parking_update
// POST /functions/v1/operator/parking_update { location_id, available_spots?, status?, capacity? }
// Writes a parking_status row with source=operator and stamps updated_by.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}

serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    const auth = req.headers.get('Authorization') ?? '';
    const supa = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });

    const { data: u } = await supa.auth.getUser();
    if (!u?.user) return new Response(JSON.stringify({ error: 'AUTH_REQUIRED' }), { status: 401, headers: { 'content-type': 'application/json' } });

    const body = await req.json().catch(() => ({} as any));
    const location_id = body.location_id as string | undefined;
    const available_spots = body.available_spots as number | undefined;
    const status = body.status as 'open'|'limited'|'full'|'unknown' | undefined;
    const capacity = body.capacity as number | undefined;
    if (!location_id) return new Response(JSON.stringify({ error: 'MISSING_LOCATION_ID' }), { status: 400, headers: { 'content-type': 'application/json' } });

    // Insert row; RLS will enforce org and access. updated_by is user id.
    const { error } = await supa.from('parking_status').insert({
      location_id,
      source: 'operator',
      available_spots: available_spots ?? null,
      capacity: capacity ?? null,
      status: status ?? 'unknown',
      updated_by: u.user.id,
    } as any);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 403, headers: { 'content-type': 'application/json' } });

    return new Response(JSON.stringify({ ok: true }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
