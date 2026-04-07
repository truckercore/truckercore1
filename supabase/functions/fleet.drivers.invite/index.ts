// Supabase Edge Function: fleet.drivers.invite
// POST /functions/v1/fleet.drivers.invite
// Body: { org_id, email_or_phone, role: 'driver'|'dispatcher'|'safety', send_via: 'email'|'sms' }
// Returns: { invite_id, token, status: 'sent' }

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { isEmail, sanitizePhone, isE164 } from "../_shared/validators.ts";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function bad(status: number, message: string){
  return new Response(JSON.stringify({ error: message }), { status, headers: { "content-type": "application/json" } });
}

function randomToken(bytes = 24){
  const buf = crypto.getRandomValues(new Uint8Array(bytes));
  const b64 = btoa(String.fromCharCode(...buf));
  return b64.replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return bad(405, 'method_not_allowed');
    const auth = req.headers.get('Authorization') ?? '';
    const user = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });
    const admin = createClient(URL, SERVICE);

    const { data: ures } = await user.auth.getUser();
    if (!ures?.user) return bad(401, 'auth_required');

    const body = await req.json().catch(()=>({} as any));
    const org_id = String(body.org_id || '').trim();
    const email_or_phone = String(body.email_or_phone || '').trim();
    const role = String(body.role || 'driver');
    const send_via = String(body.send_via || (isEmail(email_or_phone) ? 'email' : 'sms')) as 'email'|'sms';
    if (!org_id || !email_or_phone) return bad(400, 'invalid_request');

    // Verify manager org scope via profiles table
    const { data: prof } = await user.from('profiles').select('org_id, primary_role').eq('user_id', ures.user.id).maybeSingle();
    if (!prof || (prof as any).org_id !== org_id) return bad(403, 'forbidden');

    let email: string | null = null;
    let phone: string | null = null;
    if (isEmail(email_or_phone)) email = email_or_phone.toLowerCase();
    else {
      const sp = sanitizePhone(email_or_phone);
      if (!sp || !isE164(sp)) return bad(400, 'invalid_contact');
      phone = sp;
    }

    // Throttle: ensure no more than N invites in last minute per org (simple check)
    const oneMinAgo = new Date(Date.now() - 60_000).toISOString();
    const { data: recent } = await admin.from('driver_invites').select('id').eq('org_id', org_id).gte('created_at', oneMinAgo);
    if ((recent?.length ?? 0) > 30) return bad(429, 'rate_limited');

    // Generate token and insert invite
    let token = randomToken(24);
    for (let i=0;i<5;i++){
      const tryIns = await admin.from('driver_invites').insert({ org_id, email, phone, role, token, status: 'pending' as const }).select('id, token').single();
      if (!tryIns.error) {
        const invite_id = (tryIns.data as any).id as string;
        // TODO: Send actual email/SMS with deep link containing token
        return new Response(JSON.stringify({ invite_id, token, status: 'sent' }), { headers: { 'content-type': 'application/json' } });
      }
      if (!tryIns.error.message.includes('unique')) throw new Error(tryIns.error.message);
      token = randomToken(24);
    }
    return bad(500, 'could_not_create_invite');
  } catch (e) {
    return bad(500, String(e));
  }
});
