import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async () => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: health } = await sb.from("iam_health").select("*").limit(1);
  const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  const { data: last24 } = await sb
    .from("iam_audit_events")
    .select("event_type, created_at")
    .gte("created_at", since);

  const payload = {
    ts: new Date().toISOString(),
    iam_health: (health as any)?.[0] ?? {},
    audit_types_24h: (last24 || []).reduce<Record<string, number>>((acc: any, e: any) => {
      const k = e.event_type as string;
      acc[k] = (acc[k] || 0) + 1;
      return acc;
    }, {}),
  };

  await fetch(Deno.env.get("AUDIT_BUCKET_PUT_URL")!, {
    method: "PUT",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" },
  });
});
