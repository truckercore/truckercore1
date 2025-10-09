// Supabase Edge Function: fleet.invites.accept
// POST /functions/v1/fleet.invites.accept
// Body: { token }
// Returns: { user_id, org_id, role, auth_hint: 'magic_link'|'otp' }

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function bad(status: number, message: string){
  return new Response(JSON.stringify({ error: message }), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return bad(405, 'method_not_allowed');

    // Accept path requires authenticated user (mobile app session)
    const auth = req.headers.get('Authorization') ?? '';
    const user = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });
    const admin = createClient(URL, SERVICE);

    const { data: ures } = await user.auth.getUser();
    if (!ures?.user) return bad(401, 'auth_required');

    const body = await req.json().catch(()=>({} as any));
    const token = String(body.token || '').trim();
    if (!token) return bad(400, 'invalid_request');

    // Peek invite for auth_hint before consuming
    const { data: inv } = await admin.from('driver_invites').select('id, org_id, email, phone, role, status').eq('token', token).maybeSingle();
    if (!inv || (inv as any).status !== 'pending') return bad(400, 'invalid_or_used_token');

    // Execute server-side RPC to link user/org and mark accepted
    const { data: acc, error: aerr } = await admin.rpc('accept_driver_invite', { p_token: token });
    if (aerr) return bad(400, aerr.message);

    const row = Array.isArray(acc) ? acc[0] : acc;
    const auth_hint = (inv as any).email ? 'magic_link' : 'otp';

    return new Response(JSON.stringify({ user_id: row.user_id, org_id: row.org_id, role: row.role, auth_hint }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return bad(500, String(e));
  }
});
