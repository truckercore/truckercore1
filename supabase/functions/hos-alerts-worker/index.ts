import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE")!;

Deno.serve(async (req) => {
  const db = createClient(url, svc, { auth: { persistSession: false } });
  if (req.method !== "POST") return new Response("method", { status: 405 });
  try {
    const body = await req.json().catch(()=>({}));
    // Accept either a single alert or an array
    const arr = Array.isArray(body) ? body : [body];
    const rows = [] as any[];
    for (const a of arr) {
      if (!a?.org_id || !a?.driver_id || !a?.alert_code) continue;
      rows.push({
        org_id: a.org_id,
        driver_id: a.driver_id,
        truck_id: a.truck_id ?? null,
        alert_code: String(a.alert_code),
        severity: Number(a.severity ?? 1),
        alert_at: a.alert_at ? new Date(a.alert_at).toISOString() : new Date().toISOString(),
        window_start: a.window_start ? new Date(a.window_start).toISOString() : null,
        window_end: a.window_end ? new Date(a.window_end).toISOString() : null,
        meta: a.meta ?? null,
      });
    }
    if (!rows.length) return new Response(JSON.stringify({ accepted: 0 }), { headers: { "Content-Type":"application/json" }});
    const { error } = await db.from("hos_dot_alerts").insert(rows);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type":"application/json" }});
    return new Response(JSON.stringify({ accepted: rows.length }), { headers: { "Content-Type":"application/json" }});
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "Content-Type":"application/json" }});
  }
});