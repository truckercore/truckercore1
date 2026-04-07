// deno-fns/ip_appeals.ts
// Endpoint: /ip-appeals (POST create) and /ip-appeals (PATCH review)
// Minimal flow; ensure admin-only for PATCH in production.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

Deno.serve( async (req) => {
  try {
    if (req.method === 'POST') {
      const b = await req.json();
      const row = {
        ip: String(b?.ip || ''),
        org_id: b?.org_id || null,
        contact: String(b?.contact || ''),
        message: String(b?.message || ''),
        status: 'pending'
      };
      if (!row.ip || !row.contact || !row.message) return new Response('bad request', { status: 400 });
      const { error } = await db.from('ip_appeals').insert(row as any);
      if (error) return new Response(error.message, { status: 500 });
      return new Response('ok', { status: 201 });
    }
    if (req.method === 'PATCH') {
      // admin-only in production
      const b = await req.json();
      const id = String(b?.id || '');
      const status = String(b?.status || '').toLowerCase();
      if (!id || !['approved','rejected'].includes(status)) return new Response('bad request', { status: 400 });
      // On approve: remove from blocklist
      if (status === 'approved') {
        try { const { data } = await db.from('ip_appeals').select('ip').eq('id', id).maybeSingle(); if (data?.ip) await db.from('ip_blocklist').delete().eq('ip', data.ip); } catch {} // best-effort
      }
      const { error } = await db.from('ip_appeals').update({ status, reviewed_at: new Date().toISOString() }).eq('id', id);
      if (error) return new Response(error.message, { status: 500 });
      return new Response('ok');
    }
    return new Response('Method Not Allowed', { status: 405 });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
