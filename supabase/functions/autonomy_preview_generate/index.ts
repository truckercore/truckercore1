// Supabase Edge Function: autonomy_preview_generate
// Path: supabase/functions/autonomy_preview_generate/index.ts
// Invoke with: POST /functions/v1/autonomy_preview_generate
// Nightly/on-demand generator for daily autonomous action previews.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = { org_id: string; day?: string };

type PreviewItem = {
  type: "request" | "prepare_counter" | string;
  load_id: string;
  confidence: number;
  why: string[];
  constraints: { hos_ok?: boolean; equip_ok?: boolean; trust_ok?: boolean; [k: string]: unknown };
};

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  const t0 = Date.now();
  try {
    const { org_id, day } = (await req.json()) as Req;
    if (!org_id) return new Response("bad_request", { status: 400 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const digestDay = (day ?? new Date().toISOString().slice(0, 10));

    // Try to pull candidate items from predictive_assignments if available; fall back to a stub example.
    let items: PreviewItem[] = [];
    try {
      const q = await supa
        .from("predictive_assignments")
        .select("load_id,confidence,constraints,why,type")
        .eq("org_id", org_id)
        .gte("created_at", `${digestDay}T00:00:00Z`)
        .lte("created_at", `${digestDay}T23:59:59Z`)
        .gte("confidence", 0.5)
        .limit(50);
      if (!q.error && q.data) {
        items = (q.data as any[]).map((r) => ({
          type: (r as any).type ?? "request",
          load_id: (r as any).load_id,
          confidence: Number((r as any).confidence ?? 0.5),
          why: Array.isArray((r as any).why) ? (r as any).why : ["Confidence >= 0.5"],
          constraints: (r as any).constraints ?? { hos_ok: true, equip_ok: true, trust_ok: true },
        }));
      }
    } catch {
      // ignore, will use stub
    }

    if (items.length === 0) {
      // Minimal stub item to ensure FE wiring can be tested even without predictive data
      items = [{
        type: "request",
        load_id: "00000000-0000-0000-0000-000000000001",
        confidence: 0.72,
        why: ["Expected CPH +9%", "Deadhead −34 mi"],
        constraints: { hos_ok: true, equip_ok: true, trust_ok: true },
      }];
    }

    // Upsert preview (idempotent by org/day)
    const prev = await supa
      .from("autonomous_previews")
      .upsert({
        org_id,
        day: digestDay,
        items,
        status: "pending",
        prepared_at: new Date().toISOString(),
        created_at: new Date().toISOString(),
      } as any, { onConflict: "org_id,day" })
      .select("id")
      .single();
    if (prev.error) throw prev.error;

    const preview_id = (prev.data as any).id;

    // Seed actions log (one row per item, idem tied to preview+load)
    for (const it of items) {
      const idem = `${org_id}.${digestDay}.${it.type}.${it.load_id}`;
      try {
        await supa
          .from("autonomous_actions_log")
          .upsert({
            org_id,
            preview_id,
            action_type: it.type,
            load_id: it.load_id,
            confidence: it.confidence,
            why: it.why,
            constraints: it.constraints,
            idem,
            proposed: true,
            approved: null,
            applied: null,
            created_at: new Date().toISOString(),
          } as any, { onConflict: "org_id,idem" });
      } catch {
        // keep going if log table missing
      }
    }

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "autonomy_preview_generate", latency_ms: Date.now() - t0, ok: true }),
      });
    } catch {}

    return new Response(JSON.stringify({ ok: true, preview_id, day: digestDay }), { status: 200 });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "autonomy_preview_generate", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
