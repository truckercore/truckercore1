// apps/web/pages/api/exports/safety.csv.ts
import type { NextApiRequest, NextApiResponse } from "next";
import crypto from "crypto";
import z from "zod";
import { createClient } from "@supabase/supabase-js";
import { Counter, Histogram, Registry } from "prom-client";

// Metrics registry (local to this process)
const registry: Registry = (global as any).__metrics_registry || new Registry();
(global as any).__metrics_registry = registry;

const reqs = new Counter({ name: "csv_export_requests_total", help: "CSV export requests", registers: [registry] });
const errs = new Counter({ name: "csv_export_errors_total", help: "CSV export errors", registers: [registry] });
const rateLimited = new Counter({ name: "csv_export_rate_limited_total", help: "CSV rate-limited", registers: [registry] });
const truncated = new Counter({ name: "csv_export_truncated_total", help: "CSV exports truncated", registers: [registry] });
const sensitive = new Counter({ name: "csv_export_sensitive_total", help: "CSV exports with sensitive columns", registers: [registry] });
const dur = new Histogram({ name: "csv_export_duration_seconds", help: "Duration", buckets: [0.2, 0.5, 1, 2, 3, 5, 8, 13], registers: [registry] });

const SUPABASE_URL = (process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || "").replace(/\/$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY || "";
const STORAGE_BUCKET = process.env.EXPORTS_BUCKET || "private-exports";
const HARD_ROW_CAP = Number(process.env.CSV_ROW_CAP || 2_000_000);
const HARD_SIZE_CAP = Number(process.env.CSV_SIZE_CAP_BYTES || 200 * 1024 * 1024);
const DEFAULT_MAX_AGE = "no-store";

const qSchema = z.object({
  async: z.coerce.boolean().optional(),
  gzip: z.coerce.boolean().optional(),
  bom: z.coerce.boolean().optional(),
  delimiter: z.string().optional(),
  columns: z.string().optional(),
  include_sensitive: z.coerce.boolean().optional(),
  start: z.string().optional(),
  end: z.string().optional(),
});

function hashFingerprint(orgId: string | null, userId: string | null, route: string, params: any) {
  const raw = `${orgId ?? ""}:${userId ?? ""}:${route}:${JSON.stringify(params)}`;
  return crypto.createHash("sha256").update(raw).digest("hex");
}

function sanitizeFilename(s: string) {
  return s.replace(/[^a-zA-Z0-9._-]+/g, "_").slice(0, 80);
}

function neutralizeCell(val: string): string {
  if (!val) return val;
  return /^[=+\-@].*/.test(val) ? `'${val}` : val;
}

function toCSVRow(fields: string[], row: Record<string, any>, delimiter: string) {
  const escaped = fields.map((f) => {
    const v = row[f];
    let s = v == null ? "" : String(v);
    s = neutralizeCell(s);
    if (s.includes('"') || s.includes("\n") || s.includes("\r") || s.includes(delimiter)) {
      s = `"${s.replace(/"/g, '""')}"`;
    }
    return s;
  });
  return escaped.join(delimiter) + "\n";
}

function supabaseAdmin() {
  return createClient(SUPABASE_URL, SERVICE_KEY as string, { auth: { persistSession: false } });
}

async function checkRateLimit(orgId: string | null, userId: string | null) {
  try {
    const Redis = (await import("ioredis")).default;
    const url = process.env.REDIS_URL as string | undefined;
    if (!url) throw new Error("no redis");
    const redis = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 1 });
    await redis.connect().catch(() => { throw new Error("connect fail"); });
    const nowMin = Math.floor(Date.now() / 60000);
    const orgKey = `rl:csv:org:${orgId || "anon"}:${nowMin}`;
    const userKey = `rl:csv:user:${userId || "anon"}:${nowMin}`;
    const orgCap = Number(process.env.RL_ORG_PER_MIN || 5);
    const userCap = Number(process.env.RL_USER_PER_MIN || 3);
    const [orgCount, userCount] = await redis
      .multi()
      .incr(orgKey).expire(orgKey, 120)
      .incr(userKey).expire(userKey, 120)
      .exec()
      .then((r) => [Number(r?.[0]?.[1] ?? 0), Number(r?.[2]?.[1] ?? 0)]);
    await redis.quit().catch(() => {});
    if (orgCount > orgCap || userCount > userCap) {
      rateLimited.inc();
      return { ok: false, retryAfter: 60 };
    }
    return { ok: true };
  } catch {
    // memory fallback: 1/min/user, 3/min/org
    const nowMin = Math.floor(Date.now() / 60000);
    const mem = global as any;
    mem.__csv_rl ||= { user: new Map<string, number>(), org: new Map<string, number>() };
    const uKey = `${userId || "anon"}:${nowMin}`;
    const oKey = `${orgId || "anon"}:${nowMin}`;
    const uCount = (mem.__csv_rl.user.get(uKey) || 0) + 1;
    mem.__csv_rl.user.set(uKey, uCount);
    const oCount = (mem.__csv_rl.org.get(oKey) || 0) + 1;
    mem.__csv_rl.org.set(oKey, oCount);
    if (uCount > 1 || oCount > 3) {
      rateLimited.inc();
      return { ok: false, retryAfter: 60 };
    }
    return { ok: true };
  }
}

async function enqueueJob(fingerprint: string, orgId: string | null, userId: string | null, route: string, params: any) {
  const sb = supabaseAdmin();
  const { data, error } = await sb
    .from("export_jobs")
    .insert({ request_fingerprint: fingerprint, org_id: orgId, user_id: userId, route, params, status: "queued", max_attempts: 5 })
    .select("id, status")
    .single();
  if (error && String(error.message).includes("duplicate key")) {
    const existing = await sb
      .from("export_jobs")
      .select("id, status")
      .eq("request_fingerprint", fingerprint)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    return existing.data || null;
  }
  if (error) throw error;
  return data;
}

async function fetchRows(orgId: string | null, start?: string, end?: string) {
  const sb = supabaseAdmin();
  let query = sb.from("export_safety_view").select("*").order("created_at", { ascending: true });
  if (orgId) query = query.eq("org_id", orgId);
  if (start) query = query.gte("created_at", start);
  if (end) query = query.lte("created_at", end);
  const { data, error } = await query.limit(HARD_ROW_CAP + 1);
  if (error) throw error;
  return data || [];
}

function applyColumnAllowlist(rows: any[], columns?: string) {
  if (!columns) return { fields: Object.keys(rows[0] || {}), mapped: rows };
  const fields = columns.split(",").map((s) => s.trim()).filter(Boolean);
  const mapped = rows.map((r) => {
    const m: Record<string, any> = {};
    for (const f of fields) m[f] = r[f];
    return m;
  });
  return { fields, mapped };
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const stop = dur.startTimer();
  reqs.inc();
  try {
    const orgId = (req.headers["x-app-org-id"] as string) || null;
    const userId = (req.headers["x-user-id"] as string) || null;

    const rl = await checkRateLimit(orgId, userId);
    if (!rl.ok) {
      res.setHeader("Retry-After", String(rl.retryAfter || 60));
      res.status(429).json({ error: "rate_limited" });
      return;
    }

    const q = qSchema.parse({
      async: req.query.async,
      gzip: req.query.gzip,
      bom: req.query.bom,
      delimiter: req.query.delimiter,
      columns: req.query.columns,
      include_sensitive: req.query.include_sensitive,
      start: req.query.start,
      end: req.query.end,
    });

    const delimiter = q.delimiter ? decodeURIComponent(q.delimiter) : ",";
    const route = "exports/safety.csv";
    const fingerprint = hashFingerprint(orgId, userId, route, { ...q, delimiter, columns: q.columns });

    if (q.async) {
      const j = await enqueueJob(fingerprint, orgId, userId, route, q);
      res.setHeader("Cache-Control", DEFAULT_MAX_AGE);
      res.status(202).json({ job_id: j?.id, status: j?.status || "queued" });
      return;
    }

    const rows = await fetchRows(orgId, q.start, q.end);
    let partial = false;
    let usedRows = rows;
    if (rows.length > HARD_ROW_CAP) {
      usedRows = rows.slice(0, HARD_ROW_CAP);
      partial = true;
      truncated.inc();
    }

    if (q.include_sensitive) sensitive.inc();

    const { fields, mapped } = applyColumnAllowlist(usedRows, q.columns);

    const chunks: Uint8Array[] = [];
    const enc = new TextEncoder();
    if (q.bom) chunks.push(new Uint8Array([0xef, 0xbb, 0xbf]));

    const header = fields.join(delimiter) + "\n";
    chunks.push(enc.encode(header));
    let totalBytes = header.length + (q.bom ? 3 : 0);

    for (const r of mapped) {
      const line = toCSVRow(fields, r, delimiter);
      const b = enc.encode(line);
      totalBytes += b.byteLength;
      if (totalBytes > HARD_SIZE_CAP) { partial = true; truncated.inc(); break; }
      chunks.push(b);
    }

    let body = Buffer.concat(chunks as any);

    const wantGzip = String(q.gzip || "0") === "1";
    if (wantGzip) {
      const zlib = await import("zlib");
      body = zlib.gzipSync(body, { level: 6 });
    }

    const checksum = crypto.createHash("sha256").update(body).digest("hex");
    const filenameBase = sanitizeFilename(
      `safety_${orgId || "org"}_${(q.start || "").replace(/:/g, "-")}_${(q.end || "").replace(/:/g, "-")}`.replace(/_+$/,"")
    ) || "safety";
    const filename = wantGzip ? `${filenameBase}.csv.gz` : `${filenameBase}.csv`;

    if (partial) res.setHeader("X-Partial", "true");
    res.setHeader("Content-Type", wantGzip ? "application/gzip" : "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="${filename}"`);
    res.setHeader("Cache-Control", DEFAULT_MAX_AGE);
    res.setHeader("X-Checksum-SHA256", checksum);
    res.setHeader("X-Export-Id", fingerprint);
    res.setHeader("X-Row-Count", String(mapped.length));

    res.status(200).send(body);
  } catch (e: any) {
    errs.inc();
    res.status(500).json({ error: "export_failed", message: e?.message || "error" });
  } finally {
    stop();
  }
}
