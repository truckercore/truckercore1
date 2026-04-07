import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

const okRes = ok; // alias

serve(withApiShape(async (req, { requestId }) => {
  const rid = requestId || reqId();
  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE")!;
    const ADMIN_TOKEN  = Deno.env.get("ADMIN_TOKEN") || Deno.env.get("AB_ADMIN_TOKEN");
    const svc = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

    // simple admin guard (token header)
    const adminToken = req.headers.get("X-Admin-Token");
    if (!ADMIN_TOKEN || !adminToken || adminToken !== ADMIN_TOKEN) {
      logErr("ab_admin forbidden", { requestId: rid });
      return err("forbidden", "admin token required", rid, 403);
    }

    const url = new URL(req.url);
    const action = url.searchParams.get("action"); // list|create|update|pause|archive

    if (action === "list") {
      const { data, error } = await svc.from("v_ab_admin").select("*").order("start_at", { ascending: false });
      if (error) return err("db_error", error.message, rid, 500);
      logInfo("ab_admin list", { requestId: rid });
      return okRes({ items: data }, rid);
    }

    if (req.method !== "POST") return err("bad_request", "Use POST for mutations", rid, 405);
    const body = await req.json().catch(() => ({} as any));

    if (action === "create") {
      const { key, feature_key, env = "prod", weights = { A: 0.5, B: 0.5 }, start_at = null, end_at = null } = body || {};
      if (!key || !feature_key) return err("bad_request", "key and feature_key required", rid, 400);
      const { data, error } = await svc.rpc("ab_admin_create", {
        p_key: key,
        p_feature_key: feature_key,
        p_env: env,
        p_weights: weights,
        p_start: start_at,
        p_end: end_at
      });
      if (error) return err("db_error", error.message, rid, 422);
      logInfo("ab_admin created", { requestId: rid });
      return okRes({ key: data }, rid);
    }

    if (action === "update") {
      const { key, weights = null, end_at = null, status = null } = body || {};
      if (!key) return err("bad_request", "key required", rid, 400);
      const { error } = await svc.rpc("ab_admin_update", { p_key: key, p_weights: weights, p_end: end_at, p_status: status });
      if (error) return err("db_error", error.message, rid, 422);
      logInfo("ab_admin updated", { requestId: rid });
      return okRes({ key }, rid);
    }

    if (action === "pause") {
      const { key } = body || {}; if (!key) return err("bad_request", "key required", rid, 400);
      const { error } = await svc.rpc("ab_admin_pause", { p_key: key });
      if (error) return err("db_error", error.message, rid, 422);
      logInfo("ab_admin paused", { requestId: rid });
      return okRes({ key, status: "paused" }, rid);
    }

    if (action === "archive") {
      const { key } = body || {}; if (!key) return err("bad_request", "key required", rid, 400);
      const { error } = await svc.rpc("ab_admin_archive", { p_key: key });
      if (error) return err("db_error", error.message, rid, 422);
      logInfo("ab_admin archived", { requestId: rid });
      return okRes({ key, status: "archived" }, rid);
    }

    return err("bad_request", "unknown action", rid, 400);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    logErr("ab_admin unexpected", { requestId: requestId || rid });
    return err("internal_error", msg, requestId || rid, 500);
  }
}));