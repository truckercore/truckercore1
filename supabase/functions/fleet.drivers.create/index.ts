// Supabase Edge Function: fleet.drivers.create
// POST /functions/v1/fleet.drivers.create
// Body: { org_id, name, email?, phone?, license_no?, truck_id?, role }
// Returns: { user_id, driver_id, status: 'created'|'updated' }

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { requireContact, isEmail, isE164, sanitizePhone } from "../_shared/validators.ts";

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

    const auth = req.headers.get('Authorization') ?? '';
    const user = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });
    const admin = createClient(URL, SERVICE);

    const { data: ures } = await user.auth.getUser();
    if (!ures?.user) return bad(401, 'auth_required');

    const body = await req.json().catch(()=>({} as any));
    const org_id = String(body.org_id || '').trim();
    const name = String(body.name || '').trim();
    const role = String(body.role || 'driver');
    const license_no = body.license_no ? String(body.license_no) : null;
    const truck_id = body.truck_id ? String(body.truck_id) : null;
    const email = body.email ? String(body.email).trim() : '';
    const phoneRaw = body.phone ? String(body.phone).trim() : '';

    if (!org_id || !name) return bad(400, 'invalid_request');

    // Verify manager org scope via profiles table
    const { data: prof } = await user.from('profiles').select('org_id, primary_role').eq('user_id', ures.user.id).maybeSingle();
    if (!prof || (prof as any).org_id !== org_id) return bad(403, 'forbidden');

    const contact = requireContact(email || undefined, phoneRaw || undefined);
    if (!contact.ok) return bad(400, contact.reason!);

    const phone = contact.phone ?? null;
    const normEmail = contact.email ?? null;

    // Try to find existing auth user by email/phone
    let targetUserId: string | null = null;
    try {
      const adminClient: any = (admin as any);
      if (normEmail) {
        const list = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1, email: normEmail });
        const u = list?.data?.users?.find((x: any)=> x.email?.toLowerCase() === normEmail);
        if (u) targetUserId = u.id;
      }
      if (!targetUserId && phone && isE164(phone)) {
        const list = await (admin as any).auth.admin.listUsers({ page: 1, perPage: 50 });
        const u = list?.data?.users?.find((x: any)=> (x.phone ?? '').trim() === phone);
        if (u) targetUserId = u.id;
      }
    } catch {}

    // Idempotency: if a driver already exists for this org with this user/contact, update instead of new
    let driverId: string | null = null;
    if (targetUserId){
      const { data: existing } = await admin.from('drivers').select('id, user_id, org_id, status').eq('org_id', org_id).eq('user_id', targetUserId).maybeSingle();
      if (existing) driverId = (existing as any).id;
    }

    let status: 'created' | 'updated' = 'created';

    if (!driverId){
      const ins = await admin.from('drivers').insert({ org_id, user_id: targetUserId, license_no, truck_id, status: targetUserId ? 'active' : 'pending' }).select('id').single();
      if (ins.error) return bad(500, ins.error.message);
      driverId = (ins.data as any).id;
    } else {
      const up = await admin.from('drivers').update({ license_no, truck_id }).eq('id', driverId).select('id').single();
      if (up.error) return bad(500, up.error.message);
      status = 'updated';
    }

    // Ensure fleet_members upsert if we have a user
    if (targetUserId){
      await admin.from('fleet_members').insert({ org_id, user_id: targetUserId, role }).onConflict('org_id, user_id').merge();
    }

    // TODO: Billing hooks (Stripe seats): increment on active; decrement on suspend.

    return new Response(JSON.stringify({ user_id: targetUserId, driver_id: driverId, status }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return bad(500, String(e));
  }
});
