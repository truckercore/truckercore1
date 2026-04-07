// Supabase Edge Function: drivers.invite
// POST /functions/v1/drivers.invite
// Same contract as drivers.create (kept separate for future messaging hooks)

import "jsr:@supabase/functions-js/edge-runtime";
import { getClient, ensureOrgScope } from "../_shared/db.ts";
import { bad, json } from "../_shared/http.ts";
import { EMAIL_RE, PHONE_RE, ROLE_SET } from "../_shared/validation.ts";

function sanitizePhone(x?: string){
  if (!x) return null;
  const digits = x.replace(/[^\d+]/g, '');
  if (/^\+[1-9]\d{6,14}$/.test(digits)) return digits;
  const ten = x.replace(/\D/g, '');
  if (ten.length === 10) return `+1${ten}`;
  return null;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return bad(405, 'method_not_allowed');
    let body: any;
    try { body = await req.json(); } catch { return bad(400, 'invalid_json'); }

    const org_id = String(body?.org_id || '').trim();
    const role = String(body?.role || 'driver').toLowerCase();
    const emailOrPhone = String(body?.email_or_phone || '').trim();

    if (!org_id || !emailOrPhone) return bad(400, 'missing_required');
    if (!ROLE_SET.has(role as any)) return bad(422, 'invalid_role');

    let email: string | null = null;
    let phone: string | null = null;
    if (EMAIL_RE.test(emailOrPhone.toLowerCase())) email = emailOrPhone.toLowerCase();
    else {
      const p = sanitizePhone(emailOrPhone);
      if (!p || !/^\+[1-9]\d{6,14}$/.test(p)) return bad(422, 'invalid_phone_format');
      phone = p;
    }

    const requester = req.headers.get('x-user-id') ?? '';
    const admin = getClient('service');
    try { await ensureOrgScope(admin, org_id, requester); } catch { return bad(403, 'forbidden'); }

    // Duplicate within org guard
    const { data: existing } = await admin
      .from('driver_invites')
      .select('id')
      .eq('org_id', org_id)
      .or([(email?`email.eq.${email}`:''), (phone?`phone.eq.${phone}`:'')].filter(Boolean).join(','))
      .limit(1);
    if (existing && existing.length) return bad(409, 'duplicate_contact_existing');

    const token = crypto.randomUUID().replace(/-/g,'');
    const ins = await admin
      .from('driver_invites')
      .insert({ org_id, email, phone, role, token, status: 'pending' })
      .select('id, token')
      .single();
    if (ins.error) return bad(500, ins.error.message);

    return json({ invite_id: (ins.data as any).id, token: (ins.data as any).token, status: 'sent' });
  } catch (e) {
    return bad(500, String(e));
  }
});
