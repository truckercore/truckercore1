// Path: supabase/functions/quickbooks_export_invoice/index.ts
// Mock QuickBooks connector (invoice export stub)
// Invoke with: POST /functions/v1/quickbooks_export_invoice

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  try {
    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { org_id, invoice } = await req.json();
    if (!org_id || !invoice) return new Response('bad_request', { status: 400 });

    // simulate external post and record event
    const ins = await supa.from('integration_events').insert({
      org_id, provider: 'quickbooks', event_type: 'invoice.export', payload: { invoice }, status: 'ok'
    });
    if (ins.error) throw ins.error;

    return new Response(JSON.stringify({ ok:true, external_id: `QB-${crypto.randomUUID()}` }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok:false, error: String(e) }), { status: 500 });
  }
});
