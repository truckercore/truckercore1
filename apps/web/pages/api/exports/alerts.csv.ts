// apps/web/pages/api/exports/alerts.csv.ts
import type { NextApiRequest, NextApiResponse } from "next";
import crypto, { randomUUID } from "node:crypto";
import zlib from "node:zlib";
import { promisify } from "node:util";
import { createClient } from "@supabase/supabase-js";
import Redis from "ioredis";
import { Histogram, Counter, Registry, collectDefaultMetrics } from "prom-client";

const gzipAsync = promisify(zlib.gzip);

const SUPABASE_URL = (process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || "").replace(/\/$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY || "";
const ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "";
const REDIS_URL = process.env.REDIS_URL || process.env.UPSTASH_REDIS_REST_URL || "";
const REDIS_TOKEN = process.env.REDIS_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN || "";

// Prometheus metrics (singleton via global cache)
const globalAny = global as any;
const promRegistry = globalAny.promRegistry || new Registry();
if (!globalAny.promRegistry) {
  collectDefaultMetrics({ register: promRegistry });
  globalAny.promRegistry = promRegistry;
}

const mRequests = new Counter({
  name: "csv_export_requests_total",
  help: "CSV export requests",
  labelNames: ["route", "org_id", "status"],
  registers: [promRegistry],
});
const mErrors = new Counter({
  name: "csv_export_errors_total",
  help: "CSV export errors",
  labelNames: ["route", "reason"],
  registers: [promRegistry],
});
const mRows = new Counter({
  name: "csv_export_rows_total",
  help: "CSV rows exported",
  labelNames: ["route"],
  registers: [promRegistry],
});
const mBytes = new Counter({
  name: "csv_export_bytes_total",
  help: "CSV bytes exported",
  labelNames: ["route"],
  registers: [promRegistry],
});
const mRateLimited = new Counter({
  name: "csv_export_rate_limited_total",
  help: "CSV export rate limited",
  labelNames: ["route", "org_id"],
  registers: [promRegistry],
});
const hDuration = new Histogram({
  name: "csv_export_duration_seconds",
  help: "CSV export duration",
  labelNames: ["route"],
  buckets: [0.1, 0.25, 0.5, 1, 2, 5, 10],
  registers: [promRegistry],
});

const ROUTE = "export-alerts.csv";
const LIMITS = {
  syncMaxRows: 50000,
  asyncMaxRows: 500000,
  syncMaxBytes: 10 * 1024 * 1024, // 10 MB
};
const RL = {
  perUserPerMin: 5,
  perOrgPerHour: 50,
  burstMultiplier: 2,
};

type CsvOpts = {
  bom?: boolean;
  gzip?: boolean;
  filename?: string;
  includeSensitive?: boolean;
  columns?: string[];
  delimiter?: string; // default ','
};

function getClient(service = true) {
  return createClient(SUPABASE_URL, service ? (SERVICE_KEY as string) : (ANON_KEY as string), {
    auth: { persistSession: false },
  });
}

function sanitizeFilename(s: string) {
  return s.replace(/[^A-Za-z0-9._-]+/g, "_").slice(0, 80);
}

function needsInjectionPrefix(v: string): boolean {
  return /^[=+\-@]/.test(v);
}

function escCell(v: any, delimiter: string): string {
  if (v == null) return "";
  if (typeof v === "object") v = JSON.stringify(v);
  let s = String(v);
  // CSV/TSV injection safety
  if (s && needsInjectionPrefix(s)) s = "'" + s;
  const mustQuote = s.includes(delimiter) || s.includes('"') || s.includes("\n") || s.includes("\r");
  if (mustQuote) s = `"${s.replace(/"/g, '""')}"`;
  return s;
}

function toCSV(rows: any[], delimiter = ",", columns?: string[], bom = false): Buffer {
  if (!rows || rows.length === 0) return Buffer.from(bom ? "\uFEFF" : "", "utf8");
  const cols = columns && columns.length ? columns : Object.keys(rows[0]);
  const header = cols.join(delimiter);
  const body = rows.map((r) => cols.map((c) => escCell(r[c], delimiter)).join(delimiter)).join("\n");
  const text = `${header}\n${body}`;
  const payload = bom ? "\uFEFF" + text : text;
  return Buffer.from(payload, "utf8");
}

async function sha256(buf: Buffer): Promise<string> {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

function getUserOrgFromReq(req: NextApiRequest): { orgId?: string; userId?: string } {
  const org = req.headers["x-app-org-id"]; // prefer proxy/middleware header
  const user = req.headers["x-user-id"] || req.headers["x-supabase-uid"];
  return {
    orgId: Array.isArray(org) ? org[0] : (org as string | undefined),
    userId: Array.isArray(user) ? user[0] : (user as string | undefined),
  };
}

async function auditLog(entry: {
  org_id?: string;
  user_id?: string;
  route: string;
  row_count: number;
  bytes: number;
  checksum: string;
  include_sensitive: boolean;
  columns?: string[];
}) {
  try {
    if (!SUPABASE_URL || !SERVICE_KEY) return;
    const supa = getClient(true);
    // Use existing export_audit schema (id bigserial exists in repo); don't set id explicitly
    await supa.from("export_audit").insert({
      org_id: entry.org_id || null,
      user_id: entry.user_id || null,
      route: entry.route,
      row_count: entry.row_count,
      bytes: entry.bytes,
      checksum: entry.checksum,
      include_sensitive: entry.include_sensitive,
      columns: entry.columns || null,
    } as any);
  } catch {
    // swallow
  }
}

async function rateLimitCheck(orgId: string | undefined, userId: string | undefined): Promise<{ ok: boolean; retryAfter?: number }> {
  if (!REDIS_URL) return { ok: true };
  const redis = REDIS_TOKEN ? new Redis(REDIS_URL, { password: REDIS_TOKEN, lazyConnect: true }) : new Redis(REDIS_URL, { lazyConnect: true });
  try {
    await redis.connect();
    const route = ROUTE;
    const now = Math.floor(Date.now() / 1000);
    const org = orgId || "unknown";
    const user = userId || "anon";

    // Optional multiplier
    const mulKey = `rl:csv:org:${org}:multiplier`;
    const mul = Number((await redis.get(mulKey)) || "1") || 1;

    // Sliding windows (coarse, per-minute/hour buckets)
    const perUserKey = `rl:csv:v1:${org}:${user}:${route}:m${Math.floor(now / 60)}`;
    const perOrgKey = `rl:csv:v1:${org}:__ORG__:${route}:h${Math.floor(now / 3600)}`;
    const userCap = RL.perUserPerMin * RL.burstMultiplier;
    const orgCap = RL.perOrgPerHour * RL.burstMultiplier * mul;

    const pipe = redis.multi();
    pipe.incr(perUserKey); pipe.expire(perUserKey, 120);
    pipe.incr(perOrgKey);  pipe.expire(perOrgKey, 7200);
    const resp = await pipe.exec();
    const userCount = Number(resp?.[0]?.[1] || 0);
    const orgCount = Number(resp?.[2]?.[1] || 0);

    await redis.quit();

    if (userCount > userCap || orgCount > orgCap) {
      return { ok: false, retryAfter: 60 };
    }
    return { ok: true };
  } catch {
    // Fail-open minimal
    try { await redis.quit(); } catch {}
    return { ok: true };
  }
}

async function fetchRows(orgId?: string, includeSensitive = false, columns?: string[]): Promise<any[]> {
  // Server-only service role; use masked/secure view if available
  const supa = getClient(true);
  let q = supa.from("v_export_alerts").select(columns && columns.length ? columns.join(",") : "*", { head: false });
  if (orgId) q = q.eq("org_id", orgId);
  if (!includeSensitive) {
    // Exclude potential PII columns if present
    const deny = ["driver_email", "driver_phone"];
    if (!columns || columns.length === 0) {
      q = supa.from("v_export_alerts").select("* EXCEPT(driver_email,driver_phone)");
      if (orgId) q = q.eq("org_id", orgId);
    } else {
      const filtered = columns.filter((c) => !deny.includes(c));
      q = supa.from("v_export_alerts").select(filtered.join(","));
      if (orgId) q = q.eq("org_id", orgId);
    }
  }
  const { data, error } = await q.limit(LIMITS.asyncMaxRows);
  if (error) throw error;
  return data || [];
}

async function startAsyncJob(params: { exportId: string; orgId?: string; userId?: string; options: CsvOpts }) {
  if (!SUPABASE_URL || !SERVICE_KEY) return;
  const supa = getClient(true);
  const { exportId, orgId, userId, options } = params;
  await supa.from("export_jobs").insert({
    id: exportId,
    route: ROUTE,
    org_id: orgId || null,
    user_id: userId || null,
    status: "queued",
    options,
    created_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 15 * 60_000).toISOString(),
  } as any);
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const endTimer = hDuration.labels(ROUTE).startTimer();
  const exportId = randomUUID();
  const { orgId, userId } = getUserOrgFromReq(req);

  // Rate limit
  const rl = await rateLimitCheck(orgId, userId);
  if (!rl.ok) {
    mRateLimited.labels(ROUTE, String(orgId || "unknown")).inc();
    mRequests.labels(ROUTE, String(orgId || "unknown"), "429").inc();
    res.setHeader("Retry-After", String(rl.retryAfter || 60));
    res.setHeader("Cache-Control", "no-store");
    res.status(429).json({ error: "rate_limited", retry_after: rl.retryAfter || 60 });
    endTimer();
    return;
  }

  try {
    if (req.method !== "GET") {
      res.setHeader("Allow", "GET");
      res.status(405).end("Method Not Allowed");
      endTimer();
      return;
    }
    if (!SUPABASE_URL || !SERVICE_KEY) {
      res.status(500).end("Server misconfigured");
      endTimer();
      return;
    }

    // Parse options
    const qs = req.query;
    const includeSensitive = qs.include_sensitive === "1";
    const delimiter = qs.delimiter === "\\t" || qs.delimiter === "tab" ? "\t" : (typeof qs.delimiter === "string" ? (qs.delimiter as string) : ",");
    const bom = qs.bom === "1";
    const forceGzip = qs.gzip === "1";
    const filenameSlug = sanitizeFilename((qs.filename as string) || "alerts");
    const columns = typeof qs.columns === "string" && qs.columns ? (qs.columns as string).split(",").map((s) => s.trim()).filter(Boolean) : undefined;

    // Sensitive gate logging only (actual denial handled via masking above)
    if (includeSensitive) {
      // eslint-disable-next-line no-console
      console.log("[export] include_sensitive=1", { orgId, userId, route: ROUTE, exportId });
    }

    // Fetch rows
    const rows = await fetchRows(orgId, includeSensitive, columns);
    const rowCount = rows.length;

    // Backpressure thresholds
    if (rowCount > LIMITS.syncMaxRows) {
      await startAsyncJob({ exportId, orgId, userId, options: { bom, gzip: forceGzip, filename: filenameSlug, includeSensitive, columns, delimiter } });
      mRequests.labels(ROUTE, String(orgId || "unknown"), "202").inc();
      res.setHeader("X-Export-Id", exportId);
      res.setHeader("Cache-Control", "no-store");
      res.status(202).json({ export_job_id: exportId, status: "queued" });
      endTimer();
      return;
    }

    let out = toCSV(rows, delimiter, columns, bom);
    const checksumPlain = await sha256(out);
    // Compress if large or requested
    const shouldGzip = forceGzip || out.byteLength > 256 * 1024;
    if (shouldGzip) {
      out = await gzipAsync(out, { level: zlib.constants.Z_BEST_SPEED });
    }

    if (out.byteLength > LIMITS.syncMaxBytes) {
      await startAsyncJob({ exportId, orgId, userId, options: { bom, gzip: true, filename: filenameSlug, includeSensitive, columns, delimiter } });
      mRequests.labels(ROUTE, String(orgId || "unknown"), "202").inc();
      res.setHeader("X-Export-Id", exportId);
      res.setHeader("Cache-Control", "no-store");
      res.status(202).json({ export_job_id: exportId, status: "queued" });
      endTimer();
      return;
    }

    // Metrics + audit
    mRows.labels(ROUTE).inc(rowCount);
    mBytes.labels(ROUTE).inc(out.byteLength);
    await auditLog({
      org_id: orgId,
      user_id: userId,
      route: ROUTE,
      row_count: rowCount,
      bytes: out.byteLength,
      checksum: checksumPlain,
      include_sensitive: includeSensitive,
      columns,
    });

    // Emit
    mRequests.labels(ROUTE, String(orgId || "unknown"), "200").inc();
    endTimer();

    const headers: Record<string, string> = {
      "X-Export-Id": exportId,
      "X-Row-Count": String(rowCount),
      "X-Checksum-SHA256": checksumPlain,
      "Cache-Control": "no-store",
      "Content-Disposition": `attachment; filename="${filenameSlug}-${new Date().toISOString().slice(0,10).replace(/-/g,'')}.csv"`,
    };
    if (shouldGzip) headers["Content-Encoding"] = "gzip";
    // Include content type even if gzipped (encoding header informs clients)
    headers["Content-Type"] = "text/csv; charset=utf-8";

    res.writeHead(200, headers);
    res.end(out);
  } catch (e: any) {
    mErrors.labels(ROUTE, e?.code || "unknown").inc();
    mRequests.labels(ROUTE, String(orgId || "unknown"), "500").inc();
    res.setHeader("Cache-Control", "no-store");
    res.status(500).json({ error: "export_failed" });
    endTimer();
  }
}
