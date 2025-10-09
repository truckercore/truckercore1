// scripts/jobs/export_worker.ts
// Run once to process a few queued export jobs and upload .csv.gz to the private 'exports' bucket
import { createClient } from "@supabase/supabase-js";
import zlib from "node:zlib";
import { promisify } from "node:util";

const gzipAsync = promisify(zlib.gzip);

function needsInjectionPrefix(v: string): boolean {
  return /^[=+\-@]/.test(v);
}
function escCell(v: any, delimiter: string): string {
  if (v == null) return "";
  if (typeof v === "object") v = JSON.stringify(v);
  let s = String(v);
  if (s && needsInjectionPrefix(s)) s = "'" + s;
  const mustQuote = s.includes(delimiter) || s.includes('"') || s.includes("\n") || s.includes("\r");
  if (mustQuote) s = `"${s.replace(/"/g, '""')}"`;
  return s;
}
function toCSV(rows: any[], delimiter = ",", columns?: string[], bom = false): Buffer {
  if (!rows || rows.length === 0) return Buffer.from(bom ? "\uFEFF" : "", "utf8");
  const cols = columns && columns.length ? columns : Object.keys(rows[0] || {});
  const header = cols.join(delimiter);
  const body = rows.map((r) => cols.map((c) => escCell(r[c], delimiter)).join(delimiter)).join("\n");
  const text = `${header}\n${body}`;
  const payload = bom ? "\uFEFF" + text : text;
  return Buffer.from(payload, "utf8");
}

async function runOnce() {
  const SUPABASE_URL = (process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || "").replace(/\/$/, "");
  const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("Missing SUPABASE_URL or service role key env");
    process.exit(1);
  }
  const supa = createClient(SUPABASE_URL, SERVICE_KEY as string, { auth: { persistSession: false } });

  const { data: jobs, error: jerr } = await supa
    .from("export_jobs")
    .select("id, route, org_id, user_id, options")
    .eq("status", "queued")
    .order("created_at", { ascending: true })
    .limit(5);
  if (jerr) throw jerr;
  if (!jobs || jobs.length === 0) return;

  for (const job of jobs) {
    await supa.from("export_jobs").update({ status: "running", updated_at: new Date().toISOString() }).eq("id", job.id);
    try {
      const opts = (job as any).options || {};
      const delimiter = opts.delimiter || ",";
      const bom = !!opts.bom;
      const columns: string[] | undefined = opts.columns;
      const includeSensitive = !!opts.includeSensitive;

      // fetch data (mirror of API projection)
      let q = supa.from("v_export_alerts").select(columns && columns.length ? columns.join(",") : "*");
      if (job.org_id) q = q.eq("org_id", job.org_id);
      if (!includeSensitive && (!columns || columns.length === 0)) {
        q = supa.from("v_export_alerts").select("* EXCEPT(driver_email,driver_phone)");
        if (job.org_id) q = q.eq("org_id", job.org_id);
      }
      const { data: rows, error } = await q.limit(500000);
      if (error) throw error;

      const buf = toCSV(rows || [], delimiter, columns, bom);
      const gz = await gzipAsync(buf, { level: zlib.constants.Z_BEST_SPEED });

      // store to storage bucket 'exports'
      const filename = `${job.route}/${job.id}.csv.gz`;
      const { error: upErr } = await supa.storage
        .from("exports")
        .upload(filename, gz, { contentType: "text/csv", upsert: true, cacheControl: "no-store", contentEncoding: "gzip" });
      if (upErr) throw upErr;

      const { data: signed } = await supa.storage.from("exports").createSignedUrl(filename, 15 * 60); // 15m
      await supa
        .from("export_jobs")
        .update({ status: "done", signed_url: signed?.signedUrl || null, updated_at: new Date().toISOString(), expires_at: new Date(Date.now() + 7*24*3600*1000).toISOString() })
        .eq("id", job.id);
    } catch (e: any) {
      await supa
        .from("export_jobs")
        .update({ status: "failed", error: String(e?.message || e), updated_at: new Date().toISOString() })
        .eq("id", job.id);
    }
  }
}

if (require.main === module) {
  runOnce().catch((e) => { console.error(e); process.exit(1); });
}

export async function runExportWorkerOnce() {
  await runOnce();
}
