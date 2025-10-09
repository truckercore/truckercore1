// functions/calendar_sync_events/index.ts
// POST in: { org_id, range:{from,to}, idem? }
// OUT: { ok, created:int, updated:int, duplicated?: boolean, job_id }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { hmacValid } from "./utils.ts";

type Req = { org_id: string; range: { from: string; to: string }; idem?: string };
type Res = { ok: boolean; created?: number; updated?: number; duplicated?: boolean; job_id?: string; error?: string };

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

    if (!body?.org_id || !body?.range?.from || !body?.range?.to) return json({ ok: false, error: "bad_request" } satisfies Res, 400);

    // Idempotency: prior job result
    {
      const { data: prior } = await supa
        .from("connector_jobs")
        .select("id, status, result")
        .eq("org_id", body.org_id)
        .eq("kind", "calendar_sync")
        .contains("params", { idem })
        .order("created_at", { ascending: false })
        .limit(1);
      if (prior && prior.length) {
        const r = prior[0] as any;
        if (r.status === "ok" && r.result) {
          return json({ ok: true, created: r.result.created ?? 0, updated: r.result.updated ?? 0, duplicated: true, job_id: r.id } satisfies Res);
        }
      }
    }

    // Enqueue job
    const { data: jobRow, error: insErr } = await supa
      .from("connector_jobs")
      .insert({
        org_id: body.org_id,
        kind: "calendar_sync",
        params: { range: body.range, idem },
        status: "queued",
      })
      .select("id")
      .single();
    if (insErr || !jobRow) return json({ ok: false, error: `enqueue_failed: ${insErr?.message}` } satisfies Res, 500);

    const job_id = (jobRow as any).id as string;

    // Mark running
    await supa.from("connector_jobs").update({ status: "running" }).eq("id", job_id);

    // TODO: Replace with real provider sync (Google/Microsoft)
    const created = 2;
    const updated = 1;

    const { error: updErr } = await supa
      .from("connector_jobs")
      .update({ status: "ok", result: { created, updated }, finished_at: new Date().toISOString() })
      .eq("id", job_id);
    if (updErr) return json({ ok: false, error: `finalize_failed: ${updErr.message}`, job_id } satisfies Res, 500);

    return json({ ok: true, created, updated, job_id } satisfies Res);
  } catch (e) {
    return json({ ok: false, error: String(e) } satisfies Res, 500);
  }
});