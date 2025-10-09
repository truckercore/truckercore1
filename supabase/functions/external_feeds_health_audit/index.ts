// Supabase Edge Function: external_feeds_health_audit
// Reads external_feeds.registry and external_feeds.health to write health_audit entries.
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

Deno.serve(async () => {
  const { data: feeds, error: regErr } = await sb
    .schema("external_feeds")
    .from("registry")
    .select("feed_key, sla_seconds");

  if (regErr) return new Response(regErr.message, { status: 500 });
  if (!feeds?.length) return new Response("no feeds", { status: 200 });

  for (const f of feeds as any[]) {
    const { data: health, error: hErr } = await sb
      .schema("external_feeds")
      .from("health")
      .select("seconds_since_update")
      .eq("feed_key", f.feed_key)
      .maybeSingle();

    if (hErr) continue;
    const ssu = (health as any)?.seconds_since_update ?? 999999;

    await sb
      .schema("external_feeds")
      .from("health_audit")
      .insert({ feed_key: f.feed_key, seconds_since_update: ssu });
  }

  return new Response(JSON.stringify({ ok: true }), { status: 200 });
});
