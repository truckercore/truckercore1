import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

/**
 * Body: { incident_id: string, path: string, expires_sec?: number }
 * Security model now: any authenticated can request; you can add stronger checks later
 * (e.g., only incident owner/manager) if your schema has that notion.
 */
Deno.serve(async (req) => {
  try {
    const { incident_id, path, expires_sec } = await req.json();
    if (!incident_id || !path) {
      return new Response(JSON.stringify({ error: 'incident_id and path required' }), { status: 400 });
    }

    // Confirm incident exists (basic gate)
    const { data: inc, error: iErr } = await sb
      .from('safety_incidents')
      .select('id, attachments')
      .eq('id', incident_id)
      .maybeSingle();
    if (iErr || !inc) return new Response(JSON.stringify({ error: iErr?.message || 'incident not found' }), { status: 404 });

    // Optional: verify path is listed in attachments
    const listed = (inc as any).attachments ? (inc as any).attachments.some((a: any) => a?.path === path) : false;
    if (!listed) {
      return new Response(JSON.stringify({ error: 'path not registered on incident' }), { status: 403 });
    }

    const seconds = Math.max(60, Math.min(3600, Number(expires_sec) || 600));

    const { data, error } = await sb.storage
      .from('incident-photos')
      .createSignedUrl(path, seconds);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

    return new Response(JSON.stringify({ url: data?.signedUrl }), { status: 200 });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e?.message || 'unknown' }), { status: 500 });
  }
});
