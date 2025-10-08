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
  if (!SUPABASE_URL || !ANON) return bad("Server misconfigured", 500);

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
  const fname = `alerts_${appOrgId}_${start ?? "all"}_${end ?? "all"}.csv`;

  return new Response(csv, {
    status: 200,
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="${fname}"`,
      "cache-control": "no-store",
    },
  });
});