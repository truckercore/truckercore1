// functions/marketplace/match_load/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

function bad(status: number, msg: string) {
  return new Response(JSON.stringify({ error: msg }), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return bad(405, "method_not_allowed");
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  let body: any;
  try { body = await req.json(); } catch { return bad(400, "invalid_json"); }

  const bid_id = body?.bid_id as string | undefined;
  const actor_org = body?.actor_org as string | undefined; // optional; for auditing/guard
  if (!bid_id) return bad(422, "missing_bid_id");

  const { data, error } = await supabase.rpc('fn_match_load', { p_bid_id: bid_id, p_actor_org: actor_org ?? null });
  if (error) return bad(400, error.message);
  return new Response(JSON.stringify(data ?? { ok: true }), { headers: { "content-type": "application/json" } });
});
