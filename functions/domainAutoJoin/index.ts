import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// domainAutoJoin: POST { email }
// Behavior: If email domain matches an org's claimed domain and seats are available,
// upsert org_users row with status 'pending' (role 'viewer' by default).
// Requires Authorization: Bearer <user_jwt> so we can associate the current user.
// Uses service role key for DB writes; we only trust the email domain, not the email identity.

async function safeAuditInsert(supa: ReturnType<typeof createClient>, evt: Record<string, unknown>) {
  try {
    // Best-effort audit writing. If table/policy not present, ignore.
    await supa.from("audit_events").insert({
      id: crypto.randomUUID?.() ?? undefined,
      type: evt.type ?? 'domain_auto_join',
      created_at: new Date().toISOString(),
      actor_user_id: (evt as any).actor_user_id ?? null,
      org_id: (evt as any).org_id ?? null,
      details: evt,
    } as any);
  } catch (_) {
    // ignore
  }
}

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('method_not_allowed', { status: 405 });
    }
    const authHeader = req.headers.get('Authorization') || req.headers.get('authorization');
    const jwt = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : undefined;

    const { email } = await req.json().catch(() => ({ email: undefined }));
    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return new Response(JSON.stringify({ ok: false, error: 'bad_request' }), { status: 400 });
    }
    const domain = email.split('@').pop()?.toLowerCase();
    if (!domain) {
      return new Response(JSON.stringify({ ok: false, error: 'bad_request' }), { status: 400 });
    }

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Resolve current user from provided JWT (gateway should pass it through)
    let actorUserId: string | null = null;
    try {
      if (jwt) {
        const userRes = await (supa as any).auth.getUser(jwt);
        actorUserId = userRes?.data?.user?.id ?? null;
      }
    } catch (_) {
      // ignore; treat as unauthenticated
    }
    if (!actorUserId) {
      // For security, require a valid session so we don't auto-join arbitrary emails
      return new Response(JSON.stringify({ ok: false, error: 'unauthorized' }), { status: 401 });
    }

    // Find org by claimed domain
    const { data: org, error: orgErr } = await supa
      .from('orgs')
      .select('id, seats_total, seats_used, seats_used_pending')
      .eq('email_domain', domain)
      .maybeSingle();

    if (orgErr) throw orgErr;
    if (!org) {
      await safeAuditInsert(supa, { type: 'domain_auto_join.miss', actor_user_id: actorUserId, email, domain });
      return new Response(JSON.stringify({ ok: false, error: 'domain_not_claimed' }), { status: 404 });
    }

    const seatsAvail = (org.seats_total - (org.seats_used + org.seats_used_pending)) > 0;
    if (!seatsAvail) {
      await safeAuditInsert(supa, { type: 'domain_auto_join.seats_exceeded', actor_user_id: actorUserId, org_id: org.id, email });
      return new Response(JSON.stringify({ ok: false, error: 'seats_exceeded' }), { status: 409 });
    }

    // Insert membership as pending (idempotent upsert)
    const { error: upErr } = await supa.from('org_users').upsert({
      org_id: org.id,
      user_id: actorUserId,
      role: 'viewer',
      status: 'pending',
    }, { onConflict: 'org_id,user_id' } as any);
    if (upErr) throw upErr;

    // Optionally increment pending seat count to hold a seat
    try {
      const { error: seatErr } = await supa.rpc('fn_org_seat_inc_pending', { p_org: org.id, p_n: 1 });
      if (seatErr) {
        // If RPC not present, ignore silently
      }
    } catch (_) {}

    await safeAuditInsert(supa, { type: 'domain_auto_join.success', actor_user_id: actorUserId, org_id: org.id, email });
    return new Response(JSON.stringify({ ok: true, org_id: org.id, status: 'pending' }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
