// Supabase Edge Function: drivers.accept
// POST /functions/v1/drivers.accept
// Body: { token: string; user_id: string }
// Returns: { org_id: string; role: string; status: 'accepted' }

import "jsr:@supabase/functions-js/edge-runtime";
import { getClient } from "../_shared/db.ts";
import { bad, json } from "../_shared/http.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return bad(405, 'method_not_allowed');
    let body: any;
    try { body = await req.json(); } catch { return bad(400, 'invalid_json'); }

    const token = String(body?.token || '').trim();
    const user_id = String(body?.user_id || '').trim();
    if (!token || !user_id) return bad(400, 'missing_required');

    const admin = getClient('service');

    // Validate token pending
    const { data: inv, error: invErr } = await admin
      .from('driver_invites')
      .select('id, org_id, role, status')
      .eq('token', token)
      .maybeSingle();
    if (invErr || !inv) return bad(404, 'invalid_or_used_token');
    if ((inv as any).status !== 'pending') return bad(409, 'already_processed');

    // Upsert fleet_members
    const up1 = await admin
      .from('fleet_members')
      .upsert({ org_id: (inv as any).org_id, user_id, role: (inv as any).role }, { onConflict: 'org_id,user_id' })
      .select('org_id')
      .single();
    if (up1.error) return bad(500, up1.error.message);

    // Ensure drivers row for role=driver
    if ((inv as any).role === 'driver') {
      await admin
        .from('drivers')
        .upsert({ org_id: (inv as any).org_id, user_id, status: 'active' }, { onConflict: 'user_id' });
    }

    // Mark invite accepted
    const up2 = await admin
      .from('driver_invites')
      .update({ status: 'accepted', accepted_at: new Date().toISOString() })
      .eq('id', (inv as any).id);
    if (up2.error) return bad(500, up2.error.message);

    return json({ org_id: (inv as any).org_id, role: (inv as any).role, status: 'accepted' });
  } catch (e) {
    return bad(500, String(e));
  }
});
