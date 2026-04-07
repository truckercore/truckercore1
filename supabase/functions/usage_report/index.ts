import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

serve(withApiShape(async (req, { requestId }) => {
  const rid = requestId || reqId();
  try {
    if (req.method !== "POST") return err("bad_request", "Use POST", rid, 405);
    const { start, end } = await req.json();

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Derive org_id from JWT
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    const { data: u, error: ue } = await supa.auth.getUser(token);
    if (ue || !u?.user) return err("forbidden", "Missing user", rid, 403);
    const orgId = (u.user.app_metadata as any)?.app_org_id ?? null;
    if (!orgId) return err("forbidden", "Missing org context", rid, 403);

    const { data, error } = await supa.rpc("usage_report", { p_org: orgId, p_start: start, p_end: end });
    if (error) {
      logErr("usage_report rpc error", { requestId: rid });
      return err("internal_error", error.message, rid, 500);
    }
    logInfo("usage_report ok", { requestId: rid });
    return ok({ rows: data ?? [] }, rid);
  } catch (e) {
    const msg = (e && (e as any).message) || String(e);
    logErr("usage_report unexpected", { requestId: rid });
    return err("internal_error", msg, rid, 500);
  }
}));
