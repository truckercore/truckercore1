import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

/**
 * Body: {
 *   incident_id: string,
 *   files: { path: string, kind?: 'photo'|'video'|'doc' }[]
 * }
 * It appends storage paths to the incident's attachments JSON array.
 * Ensure public.safety_incidents has a 'attachments jsonb' column; add if missing.
 */

export default async function handler(req: Request) {
  try {
    const body = await req.json().catch(() => undefined);
    const { incident_id, files } = (body || {}) as { incident_id?: string, files?: Array<{ path: string; kind?: 'photo' | 'video' | 'doc' }> };
    if (!incident_id || !Array.isArray(files) || files.length === 0) {
      return new Response(JSON.stringify({ error: 'incident_id and files[] required' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }

    // Ensure column exists (one-time): attachments jsonb via helper RPC if present
    try {
      await sb.rpc('ensure_incident_attachments');
    } catch (_) {
      // ignore if function not present; we do a defensive check below as well
    }

    // Fetch current attachments
    const { data: inc, error: gErr } = await sb
      .from('safety_incidents')
      .select('id, org_id, attachments')
      .eq('id', incident_id)
      .maybeSingle();
    if (gErr || !inc) return new Response(JSON.stringify({ error: gErr?.message || 'incident not found' }), { status: 404, headers: { 'content-type': 'application/json' } });

    const now = new Date().toISOString();
    const append = files.map((f: any) => ({ path: String(f.path), kind: (f.kind ?? 'photo') as 'photo' | 'video' | 'doc', added_at: now }));
    const existing = Array.isArray((inc as any).attachments) ? (inc as any).attachments : [];
    const merged = [...existing, ...append];

    const { error: uErr } = await sb
      .from('safety_incidents')
      .update({ attachments: merged })
      .eq('id', incident_id);
    if (uErr) return new Response(JSON.stringify({ error: uErr.message }), { status: 500, headers: { 'content-type': 'application/json' } });

    // Observability: increment metric/log on attachments update
    await logMetric('safety_incident_attachments_updated_total', 1, {
      org_id: (inc as any).org_id ?? null,
      incident_id,
      count: Array.isArray(append) ? append.length : 0,
    });

    return new Response(JSON.stringify({ saved: append.length }), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e?.message || 'unknown' }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
}

// simple log/metric helper
async function logMetric(name: string, inc: number, labels: Record<string, any>) {
  try {
    console.log(JSON.stringify({ type: 'metric', name, inc, labels, ts: new Date().toISOString() }));
    // optionally push to a metrics endpoint here
  } catch (_) {}
}

(Deno as any).serve(handler);
