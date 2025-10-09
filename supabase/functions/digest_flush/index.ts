// Supabase Edge Function: Digest Flush (deliver queued notifications after quiet hours)
// Path: supabase/functions/digest_flush/index.ts
// Schedule: every 5 minutes
// Behavior: Reads notifications_digest for items whose send_after has passed and not yet sent,
//           inserts a notification record for the user (placeholder for provider push),
//           and marks the digest rows as sent.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false }, global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );

  try {
    // 1) Fetch ready-to-send digests
    const { data: items, error } = await sb
      .from("notifications_digest")
      .select("id,user_id,title,body,route,params")
      .lte("send_after", new Date().toISOString())
      .is("sent_at", null)
      .limit(200);
    if (error) throw error;

    let sent = 0;

    for (const it of items ?? []) {
      // 2) Insert an app notification (placeholder for real push provider)
      // If you prefer to send directly to a provider, swap this insert with your provider integration.
      const ins = await sb.from("notifications").insert({
        user_id: (it as any).user_id,
        kind: "system",
        title: (it as any).title,
        body: (it as any).body,
        route: (it as any).route ?? null,
        params: (it as any).params ?? null,
      });
      if (ins.error) {
        // If we cannot insert a notification, skip marking as sent so it can retry later
        continue;
      }

      // 3) Mark the digest item as sent
      const upd = await sb
        .from("notifications_digest")
        .update({ sent_at: new Date().toISOString() })
        .eq("id", (it as any).id);
      if (!upd.error) sent++;
    }

    return new Response(JSON.stringify({ ok: true, sent }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
