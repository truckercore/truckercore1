// Export gating stub: POST /export enforces org_settings.export_controls and data_residency_region
// Logs attempts into export_logs
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const db = createClient(URL, SERVICE!, { auth: { persistSession: false } });

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  try {
    const body = await req.json().catch(() => ({} as any));
    const org_id = body?.org_id as string | undefined;
    const actor_user_id = body?.actor_user_id as string | undefined;
    const artifact = body?.artifact as string | undefined;
    const region = body?.region as string | undefined; // requested data region/location (optional)
    if (!org_id || !actor_user_id || !artifact) return json({ error: "missing org_id/actor_user_id/artifact" }, 400);

    // Fetch org settings
    const { data: settings, error } = await db.from("org_settings").select("export_controls,data_residency_region,export_allowlist").eq("org_id", org_id).maybeSingle();
    if (error) return json({ error: error.message }, 500);

    const export_controls = settings?.export_controls ?? 'restricted';
    const residency = settings?.data_residency_region ?? 'US';
    const allow = Array.isArray(settings?.export_allowlist) ? settings!.export_allowlist as string[] : [];

    // Evaluate policy
    let outcome: 'allowed' | 'blocked' = 'blocked';
    let reason = '';

    if (export_controls === 'blocked') {
      outcome = 'blocked';
      reason = 'export_controls_blocked';
    } else if (export_controls === 'restricted') {
      // Only allow if artifact matches allowlist AND (optional) region is within residency
      const allowedByName = allow.length === 0 || allow.includes(artifact);
      const regionOk = !region || region.toUpperCase() === residency.toUpperCase();
      if (allowedByName && regionOk) { outcome = 'allowed'; } else { outcome = 'blocked'; reason = allowedByName ? 'region_mismatch' : 'not_allowlisted'; }
    } else {
      // allowed
      const regionOk = !region || region.toUpperCase() === residency.toUpperCase();
      if (regionOk) outcome = 'allowed'; else { outcome = 'blocked'; reason = 'region_mismatch'; }
    }

    // Log attempt (best-effort)
    try {
      await db.from("export_logs").insert({ org_id, actor_user_id, artifact, outcome, reason });
    } catch (_) {}

    if (outcome === 'blocked') return json({ ok: false, outcome, reason }, 403);

    // Placeholder actual export action
    return json({ ok: true, outcome, artifact, residency });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
