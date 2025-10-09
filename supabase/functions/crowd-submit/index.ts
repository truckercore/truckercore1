// supabase/functions/crowd-submit/index.ts
// Accepts authenticated user submissions for crowd_reports (org-scoped via RLS).
// Env:
//  - SUPABASE_URL
//  - SUPABASE_ANON (preferred) or SUPABASE_ANON_KEY (fallback)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const anon = Deno.env.get("SUPABASE_ANON") || Deno.env.get("SUPABASE_ANON_KEY");
if (!url || !anon) {
  console.warn("[crowd-submit] Missing SUPABASE_URL or anon key env");
}

function corsHeaders(origin?: string | null) {
  return { "Access-Control-Allow-Origin": origin || "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" } as Record<string,string>;
}

function getBearer(req: Request) {
  const h = req.headers.get("authorization") || "";
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m?.[1];
}

export default Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req.headers.get('origin')) });
  try {
    const token = getBearer(req);
    if (!token) return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401, headers: corsHeaders(req.headers.get('origin')) });

    const userClient = createClient(url ?? '', anon ?? '', {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const body = await req.json(); // {kind, stop_id|station_id, value, lat, lon, org_id}
    const { kind, stop_id, station_id, value, lat, lon, org_id } = body || {};
    if (!kind || !value || !org_id) return new Response(JSON.stringify({ error: 'bad_request' }), { status: 400, headers: corsHeaders(req.headers.get('origin')) });

    const point = (lat != null && lon != null) ? `SRID=4326;POINT(${lon} ${lat})` : null;
    const { error } = await userClient.from('crowd_reports').insert([{
      org_id,
      kind,
      stop_id: stop_id ?? null,
      station_id: station_id ?? null,
      value,
      location: point,
    }]);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 403, headers: corsHeaders(req.headers.get('origin')) });

    return new Response(JSON.stringify({ ok: true }), { headers: corsHeaders(req.headers.get('origin')) });
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as any)?.message || e) }), { status: 500, headers: corsHeaders(req.headers.get('origin')) });
  }
});
