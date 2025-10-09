// deno-fns/saml_telemetry_api.ts
// Endpoint: /api/saml/telemetry?org_id=...
// Aggregates last 7 days SAML_LOGIN events from alerts_events
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

Deno.serve(async (req) => {
  const orgId = new URL(req.url).searchParams.get("org_id");
  if (!orgId) return new Response("org_id required", { status: 400 });
  const since = new Date(Date.now() - 7*24*3600*1000).toISOString();
  const { data, error } = await db
    .from("alerts_events")
    .select("payload, triggered_at")
    .eq("org_id", orgId)
    .eq("code", "SAML_LOGIN")
    .gte("triggered_at", since);
  if (error) return new Response(error.message, { status: 500 });

  const rows = (data || []).map((r: any) => ({ ms: r.payload?.ms ?? 0, ok: r.payload?.ok === true, t: r.triggered_at }));
  const ok = rows.filter(r => r.ok).length;
  const fail = rows.length - ok;
  const p95 = (() => {
    const arr = rows.map(r => r.ms).sort((a,b)=>a-b);
    if (!arr.length) return 0;
    return arr[Math.floor(arr.length * 0.95)];
  })();
  return new Response(JSON.stringify([{ t: new Date().toISOString(), ok, fail, p95_ms: p95 }]), { headers: { "content-type": "application/json" } });
});
