import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

/** Body: { load_id: string, doc_id: string, expires_sec?: number } */
Deno.serve(async (req) => {
  try {
    const { load_id, doc_id, expires_sec } = await req.json();
    const { data: doc, error } = await sb.from('shipment_documents').select('id, load_id, storage_path').eq('id', doc_id).eq('load_id', load_id).maybeSingle();
    if (error || !doc) return new Response(JSON.stringify({ error: error?.message || 'not found' }), { status: 404 });

    const { data, error: sErr } = await sb.storage.from('docs').createSignedUrl((doc as any).storage_path, Math.max(60, Math.min(3600, Number(expires_sec) || 600)));
    if (sErr) return new Response(JSON.stringify({ error: sErr.message }), { status: 500 });
    return new Response(JSON.stringify({ url: (data as any)?.signedUrl }), { status: 200 });
  } catch (e:any) {
    return new Response(JSON.stringify({ error: e?.message || 'unknown' }), { status: 500 });
  }
});
