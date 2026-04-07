// functions/tms_sync_loads/index.ts
// POST in: { org_id, since_iso, idem? }
// OUT: { ok, pulled:int, pushed:int, conflicts:int, duplicated?: boolean, job_id }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { hmacValid } from "./utils.ts";

type Req = { org_id: string; since_iso: string; idem?: string };
type Res = { ok: boolean; pulled?: number; pushed?: number; conflicts?: number; duplicated?: boolean; job_id?: string; error?: string };

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-idem-key, x-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json", ...CORS } });

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const t0 = performance.now();

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return json({ ok: false, error: "server_misconfigured" } satisfies Res, 500);
    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const raw = await req.text();
    const secret = Deno.env.get("INTEGRATIONS_SIGNING_SECRET") ?? "";
    const sigOk = await hmacValid(secret, raw, req.headers.get("x-signature"));
    if (!sigOk) return new Response("invalid signature", { status: 401, headers: CORS });
    const body = JSON.parse(raw) as Req;
    const headerIdem = req.headers.get("x-idem-key") ?? undefined;
    if (!headerIdem && !body.idem) return json({ ok: false, error: "idem_required" } satisfies Res, 400);
    const idem = body.idem ?? headerIdem!;

    if (!body?.org_id || !body?.since_iso) return json({ ok: false, error: "bad_request" } satisfies Res, 400);

    // Idempotency: check prior job by params.idem
    {
      const { data: prior } = await supa
        .from("connector_jobs")
        .select("id, status, result")
        .eq("org_id", body.org_id)
        .eq("kind", "tms_sync")
        .contains("params", { idem })
        .order("created_at", { ascending: false })
        .limit(1);
      if (prior && prior.length) {
        const r = prior[0] as any;
        if (r.status === "ok" && r.result) {
          const out = { ok: true, ...(r.result as Record<string, unknown>), duplicated: true, job_id: r.id } as Res;
          return json(out);
        }
      }
    }

    // Create job (queued)
    const { data: jobRow, error: insErr } = await supa
      .from("connector_jobs")
      .insert({
        org_id: body.org_id,
        kind: "tms_sync",
        params: { since_iso: body.since_iso, idem },
        status: "queued",
      })
      .select("id")
      .single();
    if (insErr || !jobRow) return json({ ok: false, error: `enqueue_failed: ${insErr?.message}` } satisfies Res, 500);
    const job_id = (jobRow as any).id as string;

    // Mark running
    await supa.from("connector_jobs").update({ status: "running" }).eq("id", job_id);

    // TODO: Replace with real connector logic pulling/pushing loads.
    // For MVP, simulate a small sync:
    const pulled = 5;
    const pushed = 3;
    const conflicts = 0;

    // Persist result
    const result = { pulled, pushed, conflicts, duration_ms: Math.round(performance.now() - t0) };
    const { error: updErr } = await supa
      .from("connector_jobs")
      .update({ status: "ok", result, finished_at: new Date().toISOString() })
      .eq("id", job_id);
    if (updErr) return json({ ok: false, error: `finalize_failed: ${updErr.message}`, job_id } satisfies Res, 500);

    return json({ ok: true, pulled, pushed, conflicts, job_id } satisfies Res);
  } catch (e) {
    return json({ ok: false, error: String(e) } satisfies Res, 500);
  }
});