import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type InviteItem = { email?: string; role: "admin"|"dispatcher"|"driver"|"broker"|"viewer"; driver_id?: string };
type Payload = { org_id: string; invites: InviteItem[]; mode?: "csv"|"json" };

function uid() { return crypto.randomUUID(); }
function token() { return crypto.randomUUID().replace(/-/g, ""); }

serve(async (req) => {
  try {
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const body: Payload = await req.json();

    // Seat cap check
    const { data: org, error: orgErr } = await supa
      .from("orgs")
      .select("id, seats_total, seats_used, seats_used_pending")
      .eq("id", body.org_id)
      .single();
    if (orgErr || !org) throw new Error("org_not_found");
    const needed = body.invites.length;
    const cap = org.seats_total - (org.seats_used + org.seats_used_pending);
    if (cap < needed) return new Response(JSON.stringify({ ok: false, error: "seats_exceeded", cap }), { status: 409 });

    // Create invites
    const rows = body.invites.map((i) => ({
      id: uid(),
      org_id: body.org_id,
      email: i.email ?? null,
      role: i.role,
      token: token(),
      expires_at: new Date(Date.now() + 1000 * 60 * 60 * 24 * 7).toISOString(),
      invited_by: null
    }));

    const { error: insErr } = await supa.from("org_invites").insert(rows);
    if (insErr) throw insErr;

    // Increment pending seats
    const { error: seatErr } = await supa.rpc("fn_org_seat_inc_pending", { p_org: body.org_id, p_n: needed });
    if (seatErr) throw seatErr;

    // Best-effort audit log
    try {
      await supa.from('audit_events').insert({
        id: crypto.randomUUID?.() ?? undefined,
        type: 'invites.created',
        created_at: new Date().toISOString(),
        actor_user_id: (await (supa as any).auth.getUser())?.data?.user?.id ?? null,
        org_id: body.org_id,
        details: { emails: rows.map(r => r.email), count: rows.length }
      } as any);
    } catch (_) { /* ignore */ }

    // Optional: send emails via your provider or supabase.auth.admin.inviteUserByEmail
    return new Response(JSON.stringify({ ok: true, created: rows.length, invites: rows.map(r => ({ email: r.email, token: r.token })) }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
