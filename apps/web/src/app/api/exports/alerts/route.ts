// TypeScript
import { NextRequest } from "next/server";
import { getUserAndClaims, supabaseServerClient } from "@/lib/authServer";
import { exportCounter, apiLatency } from "../../metrics/metrics";

const ALLOWED_ROLES = new Set(["admin","manager","fleet-manager","truck-stop"]);
const DATE_RX = /^\d{4}-\d{2}-\d{2}$/;
const ALLOWED_SEV = new Set(["low","medium","high","critical"]);

export async function GET(req: NextRequest) {
  const endTimer = apiLatency.startTimer({ route: "/api/exports/alerts" });
  try {
    const { user, claims } = await getUserAndClaims();
    if (!user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    if (!claims?.app_role || !ALLOWED_ROLES.has(String(claims.app_role))) {
      return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403 });
    }

    const supabase = supabaseServerClient();
    const { data: sessionData } = await supabase.auth.getSession();
    const accessToken = sessionData?.session?.access_token;
    if (!accessToken) return new Response(JSON.stringify({ error: "No access token" }), { status: 401 });

    const u = new URL(req.url);
    const start = u.searchParams.get("start");
    const end = u.searchParams.get("end");
    const severities = u.searchParams.getAll("severity");

    if (start && !DATE_RX.test(start)) return new Response(JSON.stringify({ error: "Invalid start" }), { status: 400 });
    if (end && !DATE_RX.test(end)) return new Response(JSON.stringify({ error: "Invalid end" }), { status: 400 });
    for (const s of severities) if (!ALLOWED_SEV.has(s)) return new Response(JSON.stringify({ error: "Invalid severity" }), { status: 400 });

    const qs = new URLSearchParams();
    if (start) qs.set("start", start);
    if (end) qs.set("end", end);
    for (const s of severities) qs.append("severity", s);

    const fnUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/export-alerts-csv?${qs.toString()}`;
    const resp = await fetch(fnUrl, {
      method: "GET",
      headers: { Authorization: `Bearer ${accessToken}` },
      cache: "no-store",
    });

    const body = await resp.arrayBuffer();
    const headers = new Headers(resp.headers);
    if (!headers.has("content-disposition")) headers.set("content-disposition", `attachment; filename="alerts.csv"`);
    headers.set("cache-control", "no-store");

    // Best-effort metric
    try {
      const orgId = (claims as any)?.app_org_id || "unknown";
      exportCounter.inc({ kind: "alerts_csv", org_id: String(orgId) });
    } catch {}

    return new Response(body, { status: resp.status, headers });
  } finally {
    endTimer();
  }
}
