// Supabase Edge Function: fleet.drivers.bulk_upload
// POST /functions/v1/fleet.drivers.bulk_upload
// Body: { org_id, rows: [{ name, email, phone, license_no, truck_id, role }...], dry_run? }
// Returns: { accepted: n, rejected: [{ row, reason }] }

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { requireContact } from "../_shared/validators.ts";

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
    const rows = Array.isArray(body.rows) ? body.rows : [];
    const dry_run = Boolean(body.dry_run);
    if (!org_id || rows.length === 0) return bad(400, 'invalid_request');

    // Verify manager org scope via profiles table
    const { data: prof } = await user.from('profiles').select('org_id, primary_role').eq('user_id', ures.user.id).maybeSingle();
    if (!prof || (prof as any).org_id !== org_id) return bad(403, 'forbidden');

    let accepted = 0;
    const rejected: Array<{ row: number; reason: string }> = [];

    for (let i=0;i<rows.length;i++){
      const r = rows[i] ?? {};
      const name = String(r.name || '').trim();
      if (!name){ rejected.push({ row: i, reason: 'name_required' }); continue; }
      const contact = requireContact(r.email, r.phone);
      if (!contact.ok){ rejected.push({ row: i, reason: contact.reason! }); continue; }
      accepted++;
    }

    if (!dry_run && accepted > 0){
      // Insert invites for all valid rows (do not send yet)
      for (let i=0;i<rows.length;i++){
        const r = rows[i] ?? {};
        const name = String(r.name || '').trim();
        const contact = requireContact(r.email, r.phone);
        if (!name || !contact.ok) continue;
        const token = crypto.randomUUID().replace(/-/g,'');
        await admin.from('driver_invites').insert({ org_id, email: contact.email ?? null, phone: contact.phone ?? null, role: String(r.role || 'driver'), token, status: 'pending' });
      }
    }

    return new Response(JSON.stringify({ accepted, rejected }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return bad(500, String(e));
  }
});
