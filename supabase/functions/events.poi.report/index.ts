// Supabase Edge Function: events.poi.report
// POST /functions/v1/events.poi.report
// Body: { poi_id, kind, status?, payload?, photo_url?, lat?, lng? }
// Inserts a POI report with a simple trust snapshot and basic abuse controls.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { appendAudit } from "../_shared/audit.ts";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function bad(status: number, message: string){
  return new Response(JSON.stringify({ error: message }), { status, headers: { "content-type": "application/json" } });
}

function validLatLng(lat?: number, lng?: number){
  if (lat == null || lng == null) return true;
  return Number.isFinite(lat) && Number.isFinite(lng) && lat <= 90 && lat >= -90 && lng <= 180 && lng >= -180;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return bad(405, 'method_not_allowed');
    const auth = req.headers.get('Authorization') ?? '';
    const user = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });
    const admin = createClient(URL, SERVICE);

    const { data: ures } = await user.auth.getUser();
    if (!ures?.user) return bad(401, 'auth_required');

    const body = await req.json().catch(()=>({} as any));
    const poi_id = String(body.poi_id || '').trim();
    const kind = String(body.kind || '').trim();
    const status = body.status != null ? String(body.status) : null;
    const payload = (typeof body.payload === 'object' && body.payload) ? body.payload : null;
    const photo_url = body.photo_url ? String(body.photo_url) : null;
    const lat = body.lat != null ? Number(body.lat) : undefined;
    const lng = body.lng != null ? Number(body.lng) : undefined;
    if (!poi_id || !kind) return bad(400, 'invalid_request');
    if (!['parking','weigh','incident','fuel'].includes(kind)) return bad(400, 'invalid_kind');
    if (!validLatLng(lat, lng)) return bad(400, 'invalid_coords');

    // Rate-limit: per user+poi+kind 1 per 10 minutes
    const tenMinAgo = new Date(Date.now() - 10 * 60_000).toISOString();
    const { data: recent } = await user.from('poi_reports')
      .select('id')
      .eq('user_id', ures.user.id)
      .eq('poi_id', poi_id)
      .eq('kind', kind)
      .gte('ts', tenMinAgo);
    if ((recent?.length ?? 0) > 0) return bad(429, 'rate_limited');

    // Duplicate suppression: identical status within last 5 minutes ignored
    if (status) {
      const fiveMinAgo = new Date(Date.now() - 5 * 60_000).toISOString();
      const { data: dup } = await user.from('poi_reports')
        .select('id')
        .eq('poi_id', poi_id)
        .eq('kind', kind)
        .eq('status', status)
        .gte('ts', fiveMinAgo)
        .limit(1);
      if ((dup?.length ?? 0) > 0) return bad(409, 'duplicate');
    }

    // Trust snapshot heuristic: start base 0.5, bump for account age, membership
    let trust = 0.5;
    try {
      const createdAt = new Date(ures.user.created_at).getTime();
      const ageDays = (Date.now() - createdAt) / (1000*60*60*24);
      if (ageDays > 30) trust += 0.1;
      if (ures.user.email_confirmed_at) trust += 0.05;
      // Fleet membership check (optional)
      const { data: fm } = await user.from('fleet_members').select('org_id').eq('user_id', ures.user.id).limit(1);
      if ((fm?.length ?? 0) > 0) trust += 0.1;
      trust = Math.max(0.1, Math.min(0.99, trust));
    } catch {}

    const row: any = {
      user_id: ures.user.id,
      poi_id,
      kind,
      status,
      payload,
      photo_url,
      trust_snapshot: Number(trust.toFixed(3)),
      lat: lat ?? null,
      lng: lng ?? null,
      ts: new Date().toISOString(),
    };

    const { data: ins, error } = await user.from('poi_reports').insert(row).select('id, trust_snapshot, ts').single();
    if (error) return bad(500, error.message);

    // Audit (best-effort)
    try { await appendAudit(admin, { action: 'poi.reported', entity: 'poi', entity_id: poi_id, actor_user_id: ures.user.id, diff: { kind, status } }); } catch (_) {}

    return new Response(JSON.stringify(ins), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return bad(500, String(e));
  }
});
