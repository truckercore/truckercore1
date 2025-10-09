import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

/** Body: { load_id: string, doc_type: 'rate_con'|'bol'|'pod'|'invoice'|'lumper'|'other', storage_path: string } */
Deno.serve(async (req) => {
  try {
    const { load_id, doc_type, storage_path } = await req.json();
    if (!load_id || !doc_type || !storage_path) return new Response(JSON.stringify({ error: 'load_id, doc_type, storage_path required' }), { status: 400 });

    // (Optional) OCR stub: call external provider here, store JSON
    const ocr_json = null;

    const { error } = await sb.from('shipment_documents').insert({ load_id, doc_type, storage_path, ocr_json });
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e:any) {
    return new Response(JSON.stringify({ error: e?.message || 'unknown' }), { status: 500 });
  }
});
