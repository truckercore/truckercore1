import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

/**
 * Body: { incident_id: string, path: string, expires_sec?: number, bucket?: string }
 * Returns a signed URL for a file path that is registered under the incident's attachments.
 */
Deno.serve(async (req) => {
  try {
    const { incident_id, path, expires_sec, bucket } = await req.json();
    if (!incident_id || !path) {
      return new Response(JSON.stringify({ error: 'incident_id and path required' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }

    // Confirm incident exists and fetch attachments
    const { data: inc, error: iErr } = await sb
      .from('safety_incidents')
      .select('id, attachments')
      .eq('id', incident_id)
      .maybeSingle();
    if (iErr || !inc) return new Response(JSON.stringify({ error: iErr?.message || 'incident not found' }), { status: 404, headers: { 'content-type': 'application/json' } });

    const attachments = (inc as any).attachments ?? [];
    const listed = Array.isArray(attachments) && attachments.some((a: any) => a?.path === path);
    if (!listed) {
      return new Response(JSON.stringify({ error: 'path not registered on incident' }), { status: 403, headers: { 'content-type': 'application/json' } });
    }

    const seconds = Math.max(60, Math.min(3600, Number(expires_sec) || 600));
    const bucketName = String(bucket || 'incident-photos');

    const { data, error } = await sb.storage
      .from(bucketName)
      .createSignedUrl(path, seconds);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' } });

    return new Response(JSON.stringify({ url: data?.signedUrl }), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e?.message || 'unknown' }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
