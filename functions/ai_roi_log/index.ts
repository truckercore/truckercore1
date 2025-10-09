// functions/ai_roi_log/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const URL = Deno.env.get("SUPABASE_URL")!; const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;

Deno.serve(async (req) => {
  try {
    const db = createClient(URL, KEY, { auth: { persistSession: false } });
    const b = await req.json(); // { org_id, module, estimated_savings_usd, period_start?, period_end?, dims? }
    if (!b || !b.org_id || !b.module || typeof b.estimated_savings_usd !== 'number') {
      return new Response(JSON.stringify({ error: 'bad_input' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }
    await db.from("ai_roi").insert({
      org_id: b.org_id, module: b.module, estimated_savings_usd: b.estimated_savings_usd,
      period_start: b.period_start ?? null, period_end: b.period_end ?? null, dims: b.dims ?? {}
    }, { returning: "minimal" });
    return new Response("ok");
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), { status: 400, headers: { 'content-type': 'application/json' } });
  }
});
