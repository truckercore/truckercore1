import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE")!;

Deno.serve(async () => {
  const db = createClient(url, svc, { auth: { persistSession: false } });
  // Dequeue a small batch of queued items
  const { data, error } = await db.from("accounting_sync_queue").select("id, org_id, provider, entity_type, entity_id, op, attempts").eq("status","queued").order("created_at", { ascending: true }).limit(20);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

  let processed = 0;
  for (const row of (data ?? [])) {
    try {
      // Mark processing
      await db.from("accounting_sync_queue").update({ status: "processing" }).eq("id", row.id);
      // TODO: call provider adapter based on row.provider & op
      await new Promise((r) => setTimeout(r, 30));
      // Mark success
      await db.from("accounting_sync_queue").update({ status: "success", last_error: null, updated_at: new Date().toISOString() }).eq("id", row.id);
      processed++;
    } catch (e) {
      await db.from("accounting_sync_queue").update({ status: "error", attempts: (row.attempts ?? 0) + 1, last_error: String(e), updated_at: new Date().toISOString() }).eq("id", row.id);
    }
  }
  return new Response(JSON.stringify({ ok: true, processed }), { headers: { "Content-Type": "application/json" }});
});