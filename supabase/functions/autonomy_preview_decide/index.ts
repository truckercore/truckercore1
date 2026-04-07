// Supabase Edge Function: autonomy_preview_decide
// Path: supabase/functions/autonomy_preview_decide/index.ts
// Invoke with: POST /functions/v1/autonomy_preview_decide
// Batch approve/reject a daily autonomous preview; enqueue actions only on approval.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = { org_id: string; preview_id: string; decision: "approve" | "reject"; decided_by?: string };

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  try {
    const { org_id, preview_id, decision, decided_by } = (await req.json()) as Req;
    if (!org_id || !preview_id) return new Response("bad_request", { status: 400 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Update preview header
    const st = decision === "approve" ? "approved" : "rejected";
    await supa
      .from("autonomous_previews")
      .update({ status: st, decided_at: new Date().toISOString(), decided_by: decided_by ?? null })
      .eq("id", preview_id)
      .eq("org_id", org_id);

    // Update actions log approval flags
    await supa
      .from("autonomous_actions_log")
      .update({ approved: (decision === "approve"), decided_at: new Date().toISOString() })
      .eq("preview_id", preview_id)
      .eq("org_id", org_id);

    // Enqueue execution if approved (idempotent by idem)
    if (decision === "approve") {
      const actions = await supa
        .from("autonomous_actions_log")
        .select("idem,action_type,load_id")
        .eq("preview_id", preview_id)
        .eq("org_id", org_id);
      if (actions.error) throw actions.error;

      for (const a of (actions.data ?? []) as any[]) {
        const idem = a.idem as string;
        // Idempotency: short-circuit if a connector job already exists for this idem
        const prior = await supa
          .from("connector_jobs")
          .select("id,status,result,params")
          .eq("org_id", org_id)
          .eq("kind", "dispatch_plan_propose")
          .contains("params", { idem })
          .order("created_at", { ascending: false })
          .limit(1);
        if (prior.data && prior.data.length > 0) continue;
        await supa
          .from("connector_jobs")
          .insert({
            org_id,
            kind: "dispatch_plan_propose",
            params: { type: a.action_type, load_id: a.load_id, idem },
            status: "queued",
            created_at: new Date().toISOString(),
          });
      }
    }

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "autonomy_preview_decide", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true, status: st }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "autonomy_preview_decide", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
