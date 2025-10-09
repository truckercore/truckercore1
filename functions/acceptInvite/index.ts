import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Body = { token: string; email?: string; password?: string };

serve(async (req) => {
  try {
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const body: Body = await req.json();

    const { data: inv, error: invErr } = await supa
      .from("org_invites")
      .select("id, org_id, email, role, expires_at, accepted_at")
      .eq("token", body.token)
      .single();
    if (invErr || !inv) return new Response(JSON.stringify({ ok: false, error: "invalid_token" }), { status: 400 });
    if (inv.accepted_at) return new Response(JSON.stringify({ ok: false, error: "already_accepted" }), { status: 409 });
    if (new Date(inv.expires_at) < new Date()) return new Response(JSON.stringify({ ok: false, error: "expired" }), { status: 410 });

    // seats check
    const { data: org, error: orgErr } = await supa
      .from("orgs")
      .select("id, seats_total, seats_used, seats_used_pending")
      .eq("id", inv.org_id)
      .single();
    if (orgErr || !org) throw new Error("org_not_found");
    if (org.seats_used + org.seats_used_pending >= org.seats_total) {
      return new Response(JSON.stringify({ ok: false, error: "seats_exceeded" }), { status: 409 });
    }

    // Ensure auth user exists (email or phone based)
    let authUserId: string | null = null;
    const email = body.email ?? inv.email;
    if (!email) return new Response(JSON.stringify({ ok: false, error: "email_required" }), { status: 400 });

    // Try to find existing user by email (admin API needs service key)
    const admin = (supa as any).auth.admin;
    const list = await admin.listUsers({ page: 1, perPage: 1, email });
    if (list?.data?.users?.length) {
      authUserId = list.data.users[0].id;
    } else {
      const created = await admin.createUser({
        email,
        password: body.password || crypto.randomUUID().slice(0, 12),
        email_confirm: true,
        user_metadata: { org_id: inv.org_id, app_role: inv.role }
      });
      if (created.error || !created.data.user) throw created.error || new Error("create_user_failed");
      authUserId = created.data.user.id;
    }

    // Insert org_user (idempotent)
    const { error: ouErr } = await supa.from("org_users").upsert({
      org_id: inv.org_id,
      user_id: authUserId,
      role: inv.role,
      status: "active"
    });
    if (ouErr) throw ouErr;

    // Mark invite accepted + seat accounting
    const { error: updInvErr } = await supa.from("org_invites").update({ accepted_at: new Date().toISOString() }).eq("id", inv.id);
    if (updInvErr) throw updInvErr;

    const { error: seatAcceptErr } = await supa.rpc("fn_org_seat_accept", { p_org: inv.org_id, p_n: 1 });
    if (seatAcceptErr) throw seatAcceptErr;

    // Best-effort audit log
    try {
      await supa.from('audit_events').insert({
        id: crypto.randomUUID?.() ?? undefined,
        type: 'invites.accepted',
        created_at: new Date().toISOString(),
        actor_user_id: authUserId,
        org_id: inv.org_id,
        details: { invite_id: inv.id, role: inv.role }
      } as any);
    } catch (_) { /* ignore */ }

    return new Response(JSON.stringify({ ok: true, org_id: inv.org_id, user_id: authUserId, role: inv.role }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
