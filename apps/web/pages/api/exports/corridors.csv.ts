// apps/web/pages/api/exports/corridors.csv.ts
import type { NextApiRequest, NextApiResponse } from "next";
import crypto from "crypto";

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  process.env.SUPABASE_SERVICE_ROLE ||
  process.env.SUPABASE_SERVICE_KEY;

type JwtClaims = { sub?: string; org_id?: string; app_org_id?: string };

function parseJwtOrgId(auth?: string): { userId?: string; orgId?: string } {
  if (!auth?.startsWith("Bearer ")) return {};
  const token = auth.slice("Bearer ".length);
  const parts = token.split(".");
  if (parts.length !== 3) return {};
  try {
    const payload = JSON.parse(Buffer.from(parts[1], "base64").toString("utf8")) as JwtClaims;
    return { userId: payload.sub, orgId: (payload.org_id || payload.app_org_id) as string | undefined };
  } catch {
    return {};
  }
}

// Naive in-memory rate limiter per-user (process-local)
const buckets = new Map<string, { tokens: number; ts: number }>();
function checkRate(user: string, limit = 5, windowMs = 60_000) {
  const now = Date.now();
  const b = buckets.get(user) || { tokens: limit, ts: now };
  const refill = Math.floor((now - b.ts) / windowMs);
  if (refill > 0) {
    b.tokens = Math.min(limit, b.tokens + refill);
    b.ts = now;
  }
  if (b.tokens <= 0) return { allowed: false, remaining: 0 };
  b.tokens -= 1;
  buckets.set(user, b);
  return { allowed: true, remaining: b.tokens };
}

async function auditExport(userId: string | undefined, orgId: string | undefined, ok: boolean, rowCount?: number, exportId?: string) {
  if (!SUPABASE_URL || !SERVICE_KEY) return;
  const url = `${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/export_audit`;
  await fetch(url, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      ts: new Date().toISOString(),
      user_id: userId || null,
      org_id: orgId || null,
      route: "corridors.csv",
      ok,
      row_count: rowCount ?? null,
      export_id: exportId || null,
    }),
  }).catch(() => {});
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "GET") {
    res.status(405).end("Method Not Allowed");
    return;
  }
  if (!SUPABASE_URL || !SERVICE_KEY) {
    res.status(500).end("Server misconfigured");
    return;
  }

  const auth = req.headers.authorization as string | undefined;
  const { userId, orgId: tokenOrg } = parseJwtOrgId(auth);
  const queryOrg = (req.query.org_id as string | undefined) || undefined;
  const orgId = queryOrg || tokenOrg;

  if (!userId || !orgId || tokenOrg !== orgId) {
    res.status(403).end("Forbidden");
    return;
  }

  const rate = checkRate(userId);
  res.setHeader("X-RateLimit-Limit", "5/min");
  res.setHeader("X-RateLimit-Remaining", String(rate.remaining));
  if (!rate.allowed) {
    res.status(429).end("Too Many Requests");
    return;
  }

  const exportId = crypto.randomUUID();
  try {
    const url = new URL(`${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/corridors_view`);
    url.searchParams.set("org_id", `eq.${orgId}`);
    url.searchParams.set("select", "id,org_id,name,risk_score,notes,updated_at,created_at,geojson");
    const r = await fetch(url.toString(), {
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        Accept: "text/csv",
      },
    });

    if (!r.ok) {
      const txt = await r.text();
      await auditExport(userId, orgId, false, undefined, exportId);
      res.status(r.status).end(txt);
      return;
    }

    const csv = await r.text();
    const sha = crypto.createHash("sha256").update(csv, "utf8").digest("hex");
    const rowCount = Math.max(0, (csv.match(/\n/g) || []).length - 1);

    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="corridors_${orgId}.csv"`);
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("X-Export-Id", exportId);
    res.setHeader("X-Row-Count", String(rowCount));
    res.setHeader("X-Checksum-SHA256", sha);

    await auditExport(userId, orgId, true, rowCount, exportId);
    res.status(200).end(csv);
  } catch (e: any) {
    await auditExport(userId, orgId, false, undefined, exportId);
    res.status(500).end("Export error");
  }
}