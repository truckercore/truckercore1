import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

function rid(){ return reqId(); }

serve(withApiShape(async (req, { requestId }) => {
  const r = requestId || rid();
  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE")!;
    const supa = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

    const url = new URL(req.url);
    const expKey = url.searchParams.get("exp");
    const orgId  = url.searchParams.get("org"); // optional; prefer from JWT if available
    const env    = url.searchParams.get("env") ?? "prod";
    if (!expKey) return err("bad_request", "missing exp", r, 400);

    // Fetch active experiment (env-aware, within time window)
    const nowIso = new Date().toISOString();
    const { data: exp, error: expErr } = await supa
      .from("ab_experiments")
      .select("*")
      .eq("key", expKey)
      .eq("env", env)
      .eq("status","active")
      .lte("start_at", nowIso)
      .or("end_at.is.null,end_at.gt." + nowIso)
      .single();

    if (expErr || !exp) {
      logErr("ab_assign: experiment inactive", { requestId: r });
      return err("not_found" as any, "experiment inactive", r, 404);
    }

    // Try sticky assignment if org provided
    if (orgId) {
      const { data: sticky } = await supa
        .from("ab_assignments")
        .select("variant")
        .eq("exp_key", expKey)
        .eq("org_id", orgId)
        .maybeSingle();
      if (sticky?.variant) {
        logInfo("ab_assign: sticky hit", { requestId: r });
        return ok({ variant: sticky.variant }, r);
      }
    }

    // Deterministic hash → number in [0,1)
    const basis = orgId ?? crypto.randomUUID();
    const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${expKey}:${basis}`));
    const n = new DataView(new Uint8Array(h).buffer).getUint32(0, false) / 0xffffffff;

    const weights = (exp.weights ?? {}) as Record<string, number>;
    let cum = 0; let chosen = Object.keys(weights)[0] ?? "A";
    for (const [v, w] of Object.entries(weights)) {
      cum += Number(w || 0);
      if (n <= cum) { chosen = v; break; }
    }

    // Persist sticky (best-effort)
    if (orgId) {
      await supa.from("ab_assignments").insert({ org_id: orgId, exp_key: expKey, variant: chosen }).catch(()=>{});
    }

    logInfo("ab_assign: chosen", { requestId: r });
    return ok({ variant: chosen }, r);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    logErr("ab_assign error", { requestId: r });
    return err("internal_error", msg, r, 500);
  }
}));
