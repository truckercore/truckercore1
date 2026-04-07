// Path: supabase/functions/keys_create/index.ts
// Invoke with: POST /functions/v1/keys_create

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function sha256(b: string) {
  const data = new TextEncoder().encode(b);
  return crypto.subtle.digest('SHA-256', data).then(arr => Array.from(new Uint8Array(arr)).map(x=>x.toString(16).padStart(2,'0')).join(''));
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  try {
    const { org_id } = await req.json();
    if (!org_id) return new Response('bad_request', { status: 400 });

    // generate key and hash it
    const raw = `rk_${crypto.randomUUID().replace(/-/g,'')}`;
    const hash = await sha256(raw);

    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const ins = await supa.from('api_keys').insert({ org_id, key_hash: hash }).select().maybeSingle();
    if (ins.error) throw ins.error;

    // audit
    await supa.from('activity_log').insert({
      org_id, action: 'api_key.create', target: 'self', details: { key_id: ins.data?.id }
    });

    // return raw once
    return new Response(JSON.stringify({ ok: true, key: raw, id: ins.data?.id }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok:false, error:String(e) }), { status: 500 });
  }
});
