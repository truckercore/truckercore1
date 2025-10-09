// jobs/worker_exports.ts
// Worker: consumes export_jobs using claim_export_job(), with backoff and DLQ.
import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";
import { setTimeout as wait } from "timers/promises";
import zlib from "zlib";

const SUPABASE_URL = (process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || "").replace(/\/$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY || "";
const STORAGE_BUCKET = process.env.EXPORTS_BUCKET || "private-exports";
const HARD_ROW_CAP = Number(process.env.CSV_ROW_CAP || 5_000_000);
const HARD_SIZE_CAP = Number(process.env.CSV_SIZE_CAP_BYTES || 400 * 1024 * 1024);
const POLL_MS = Number(process.env.EXPORT_WORKER_POLL_MS || 2000);

const sb = createClient(SUPABASE_URL, SERVICE_KEY as string, { auth: { persistSession: false } });

function backoff(attempt: number) {
  const base = 1000 * Math.pow(2, attempt); // 1s, 2s, 4s, ...
  return Math.min(base + Math.floor(Math.random() * 500), 60_000);
}

function neutralizeCell(val: string): string {
  if (!val) return val as any;
  return /^[=+\-@].*/.test(val) ? `'${val}` : val;
}

function toCSV(fields: string[], rows: any[], delimiter: string) {
  let size = 0;
  const out: string[] = [];
  out.push(fields.join(delimiter) + "\n");
  size += out[0].length;
  let partial = false;
  for (const r of rows) {
    const escaped = fields.map((f) => {
      let s = r[f] == null ? "" : String(r[f]);
      s = neutralizeCell(s);
      if (s.includes('"') || s.includes("\n") || s.includes("\r") || s.includes(delimiter)) s = `"${s.replace(/"/g, '""')}"`;
      return s;
    });
    const line = escaped.join(delimiter) + "\n";
    size += line.length;
    if (size > HARD_SIZE_CAP) { partial = true; break; }
    out.push(line);
  }
  return { csv: out.join(""), partial };
}

async function fetchRows(orgId: string | null, start?: string, end?: string) {
  let q = sb.from("export_safety_view").select("*").order("created_at", { ascending: true });
  if (orgId) q = q.eq("org_id", orgId);
  if (start) q = q.gte("created_at", start);
  if (end) q = q.lte("created_at", end);
  const { data, error } = await q.limit(HARD_ROW_CAP + 1);
  if (error) throw error;
  return data || [];
}

async function cycle() {
  // Claim one job via RPC
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/claim_export_job`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY as string, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: "{}",
  });
  if (!r.ok) { await wait(POLL_MS); return; }
  const job = await r.json();
  if (!job || !job.id) { await wait(POLL_MS); return; }

  try {
    const p = job.params || {};
    const delimiter = p.delimiter ? decodeURIComponent(p.delimiter) : ",";
    const wantGzip = String(p.gzip || "0") === "1";

    const rows = await fetchRows(job.org_id || null, p.start, p.end);
    const used = rows.length > HARD_ROW_CAP ? rows.slice(0, HARD_ROW_CAP) : rows;

    const fields: string[] = p.columns ? String(p.columns).split(",").map((s: string) => s.trim()).filter(Boolean) : Object.keys(used[0] || {});
    const { csv, partial } = toCSV(fields, used, delimiter);
    let buf = Buffer.from(csv, "utf8");
    if (wantGzip) buf = zlib.gzipSync(buf, { level: 6 });
    const checksum = crypto.createHash("sha256").update(buf).digest("hex");

    const safeBase = `safety_${job.org_id || "org"}_${Date.now()}`;
    const path = `${safeBase}.${wantGzip ? "csv.gz" : "csv"}`;
    const contentType = wantGzip ? "application/gzip" : "text/csv; charset=utf-8";

    const up = await sb.storage.from(STORAGE_BUCKET).upload(path, buf, { contentType, upsert: true });
    if (up.error) throw up.error;

    const { data: signed } = await sb.storage.from(STORAGE_BUCKET).createSignedUrl(path, 60 * 15);
    const artifact = signed?.signedUrl ? signed.signedUrl : `storage://${STORAGE_BUCKET}/${path}`;

    await sb.from("export_jobs")
      .update({ status: partial ? "partial" : "succeeded", artifact_url: artifact, row_count: used.length, partial, checksum_sha256: checksum, finished_at: new Date().toISOString() })
      .eq("id", job.id);
  } catch (e: any) {
    const attempts = Number(job.attempts || 0) + 1;
    const max = Number(job.max_attempts || 5);
    if (attempts >= max) {
      await sb.from("export_jobs_dlq").insert({
        job_id: job.id,
        org_id: job.org_id,
        user_id: job.user_id,
        route: job.route,
        params: job.params,
        attempts,
        reason: String(e?.message || "error"),
        stack: String(e?.stack || ""),
        payload: job,
      });
      await sb.from("export_jobs").update({ status: "failed", attempts, error_reason: String(e?.message || "error"), error_stack: String(e?.stack || "") }).eq("id", job.id);
    } else {
      const delayMs = backoff(attempts);
      const next = new Date(Date.now() + delayMs).toISOString();
      await sb.from("export_jobs").update({ status: "queued", attempts, next_run_at: next }).eq("id", job.id);
    }
  }
}

async function main() {
  process.on("SIGTERM", () => process.exit(0));
  // Loop
  // eslint-disable-next-line no-constant-condition
  while (true) {
    await cycle();
  }
}

if (require.main === module) {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    // eslint-disable-next-line no-console
    console.error("Missing SUPABASE_URL or service role key env");
    process.exit(1);
  }
  main().catch((e) => { console.error(e); process.exit(1); });
}

export async function runExportWorkerOnce() { await cycle(); }
