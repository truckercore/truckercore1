// deno-fns/quotes_legal_request.ts
// Endpoint: /api/quotes/legal_request (POST)
// Body: { org_id: string, quote_id: string, requester_id: string, notes?: string }
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE")!, { auth: { persistSession: false }});

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
  try {
    const { org_id, quote_id, requester_id, notes } = await req.json();
    if (!org_id || !quote_id || !requester_id) return new Response('bad request', { status: 400 });
    const { error } = await db.from('legal_review_requests').insert({ org_id, quote_id, requester_id, status: 'open', notes: notes ?? null });
    if (error) return new Response(error.message, { status: 500 });
    return new Response(JSON.stringify({ status: 'queued' }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
