// TypeScript
// Deno/Supabase Edge Function: export-alerts-csv
// GET /functions/v1/export-alerts-csv?start=YYYY-MM-DD&end=YYYY-MM-DD&severity=low&severity=high
// Security: verify_jwt=true (uses user token), RLS enforced.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

type Row = {
  id: string;
  corridor_id: string;
  severity: string;
  message: string;
  happened_at: string;
  metadata: { source?: string; device?: string } | null;
};

function bad(msg: string, code = 400) {
  return new Response(JSON.stringify({ error: msg }), {
    status: code,
    headers: { "content-type": "application/json" },
  });
}

function validDate(d: string | null): string | null {
  if (!d) return null;
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? d : null;
}

Deno.serve(async (req) => {
  if (req.method !== "GET") return bad("Method not allowed", 405);

  const url = new URL(req.url);
  const start = validDate(url.searchParams.get("start"));
  const end = validDate(url.searchParams.get("end"));
  const severities = url.searchParams.getAll("severity");

  const auth = req.headers.get("authorization") || "";
  if (!auth.toLowerCase().startsWith("bearer ")) {
    return bad("Missing bearer token", 401);
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("NEXT_PUBLIC_SUPABASE_ANON_KEY");
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE");
  const STORAGE_BUCKET = Deno.env.get("EXPORTS_BUCKET") ?? "exports";
  const MONTHLY_CAP = Number(Deno.env.get("EXPORT_ALERTS_MONTHLY_CAP") ?? 50);
  if (!SUPABASE_URL || !ANON || !SERVICE_KEY) return bad("Server misconfigured", 500);

  const supabase = createClient(SUPABASE_URL, ANON, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: ures, error: uerr } = await supabase.auth.getUser();
  if (uerr || !ures?.user) return bad("Invalid token", 401);

  const appRole = (ures.user.app_metadata as any)?.app_role ?? (ures.user.user_metadata as any)?.app_role;
  const appOrgId = (ures.user.app_metadata as any)?.app_org_id ?? (ures.user.user_metadata as any)?.app_org_id;
  if (!appOrgId) return bad("No organization bound to token", 403);

  const allowed = new Set(["admin", "manager", "fleet-manager", "truck-stop"]);
  if (!appRole || !allowed.has(String(appRole))) return bad("Insufficient role for export", 403);

  // Monthly cap check via export_usage
  try {
    const usageUrl = new URL(`${SUPABASE_URL}/rest/v1/export_usage`);
    usageUrl.searchParams.set("org_id", `eq.${appOrgId}`);
    usageUrl.searchParams.set("period_month", `eq.${new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1)).toISOString().slice(0,10)}`);
    usageUrl.searchParams.set("kind", `eq.alerts_csv`);
    usageUrl.searchParams.set("select", "count");
    const ur = await fetch(usageUrl.toString(), { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
    if (ur.ok) {
      const arr = await ur.json().catch(() => []);
      const used = (arr?.[0]?.count as number) ?? 0;
      if (used >= MONTHLY_CAP) {
        return new Response("Monthly export limit reached", {
          status: 402,
          headers: { "content-type": "text/plain", "x-export-used": String(used), "x-export-cap": String(MONTHLY_CAP) },
        });
      }
    }
  } catch (_) {}

  const allowedSev = new Set(["low", "medium", "high", "critical"]);
  const sevFilters = severities.filter((s) => allowedSev.has(s));

  let q = supabase
    .from("alerts")
    .select("id, corridor_id, severity, message, happened_at, metadata")
    .order("happened_at", { ascending: true });

  if (start) q = q.gte("happened_at", `${start}T00:00:00Z`);
  if (end) q = q.lte("happened_at", `${end}T23:59:59Z`);
  if (sevFilters.length) q = q.in("severity", sevFilters);

  const { data, error } = await q;
  if (error) {
    console.error("export query error", error);
    return bad("Query failed", 500);
  }

  const headers = ["id", "corridor_id", "severity", "message", "happened_at", "source", "device"];
  const escapeCSV = (v: unknown) => {
    const s = (v ?? "").toString();
    return `"${s.replace(/"/g, '""')}"`;
    };
  const lines = [headers.join(",")];
  for (const r of (data ?? []) as Row[]) {
    lines.push(
      [
        escapeCSV(r.id),
        escapeCSV(r.corridor_id),
        escapeCSV(r.severity),
        escapeCSV(r.message),
        escapeCSV(r.happened_at),
        escapeCSV(r.metadata?.source ?? ""),
        escapeCSV(r.metadata?.device ?? ""),
      ].join(",")
    );
  }
  const csv = lines.join("\r\n");
  const byteLength = new TextEncoder().encode(csv).byteLength;

  // SHA-256 digest
  const digestBuf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(csv));
  const shaHex = Array.from(new Uint8Array(digestBuf)).map((b) => b.toString(16).padStart(2, "0")).join("");

  const safe = (s: string) => s.replace(/[^a-zA-Z0-9\-_.:T]/g, "");
  const fname = `alerts_${safe(appOrgId)}_${safe(start ?? "all")}_${safe(end ?? "all")}.csv`;
  const key = `${appOrgId}/${new Date().toISOString().slice(0,10)}/${fname}`;

  // Upload to storage (best-effort)
  try {
    const putUrl = `${SUPABASE_URL}/storage/v1/object/${encodeURIComponent(STORAGE_BUCKET)}/${encodeURIComponent(key)}`;
    await fetch(putUrl, {
      method: "POST",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "text/csv; charset=utf-8", "x-upsert": "true" },
      body: csv,
    });
  } catch (_) {}

  // Insert artifact row (best-effort)
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/export_artifacts`, {
      method: "POST",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", Prefer: "resolution=merge-duplicates" },
      body: JSON.stringify({
        org_id: appOrgId,
        kind: "alerts_csv",
        from_ts: start ? `${start}T00:00:00Z` : new Date(0).toISOString(),
        to_ts: end ? `${end}T23:59:59Z` : new Date().toISOString(),
        filename: fname,
        content_type: "text/csv",
        bytes: byteLength,
        storage_path: `${STORAGE_BUCKET}/${key}`,
        sha256: shaHex,
        signed: true,
      }),
    });
  } catch (_) {}

  // Increment usage (best-effort)
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/rpc/increment_export_usage`, {
      method: "POST",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", Prefer: "params=single-object" },
      body: JSON.stringify({ p_org: appOrgId, p_kind: "alerts_csv" }),
    });
  } catch (_) {}

  return new Response(csv, {
    status: 200,
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="${fname}"`,
      "cache-control": "no-store",
      "x-artifact-sha256": shaHex,
    },
  });
});