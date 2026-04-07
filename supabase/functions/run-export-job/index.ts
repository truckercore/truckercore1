// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function metricsAdd(name: string, labels: Record<string, unknown>, delta: number) {
  await fetch(`${SUPABASE_URL}/rest/v1/rpc/metrics_add`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ p_name: name, p_labels: labels, p_delta: delta }),
  }).catch(() => {});
}

serve(async (req) => {
  try {
    if (!SUPABASE_URL || !SERVICE_KEY) return new Response("not configured", { status: 500 });
    const { job_id, jwt } = await req.json();

    // Mark running
    await fetch(`${SUPABASE_URL}/rest/v1/export_jobs?id=eq.${job_id}`, {
      method: "PATCH",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ status: "running", updated_at: new Date().toISOString() }),
    });

    // Load job
    const jr = await fetch(`${SUPABASE_URL}/rest/v1/export_jobs?id=eq.${job_id}&select=id,org_id,params`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    if (!jr.ok) throw new Error(`job read ${jr.status}`);
    const jArr = await jr.json();
    const job = jArr?.[0];
    if (!job) throw new Error("job not found");

    const params = job.params || {};
    const limit = Math.min(parseInt(String(params.limit ?? "20000"), 10) || 20000, 50000);
    const qs = new URLSearchParams();
    qs.set("select", "org_id,observed_at,urgent_count,alert_count,types,cell_geojson");
    qs.set("order", "observed_at.desc");
    qs.set("limit", String(limit));
    if (params.from) qs.set("observed_at", `gte.${params.from}`);
    if (params.to) qs.append("observed_at", `lte.${params.to}`);

    // Fetch CSV as the caller (JWT) to enforce RLS; but function has service role—PostgREST will respect the Bearer
    const r = await fetch(`${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/v_risk_corridors_export?${qs.toString()}`, {
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${jwt}`,
        Accept: "text/csv",
        "Accept-Profile": "public",
        "Content-Profile": "public",
        Prefer: "count=exact",
      },
    });
    if (!r.ok) throw new Error(`export fetch ${r.status} ${await r.text()}`);

    const csv = await r.text();
    const digest = crypto.subtle.digestSync?.("SHA-256", new TextEncoder().encode(csv));
    const sha = digest
      ? Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("")
      : "";

    // Store artifact in a table or storage; for simplicity, use storage bucket 'exports'
    const fileName = `risk_corridors/${job_id}.csv`;
    const storage = await fetch(`${SUPABASE_URL}/storage/v1/object/exports/${fileName}`, {
      method: "PUT",
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "text/csv",
        "x-upsert": "true",
        "x-checksum-sha256": sha,
      },
      body: csv,
    });
    if (!storage.ok) throw new Error(`storage put ${storage.status} ${await storage.text()}`);

    // Get signed URL (short-lived)
    const sign = await fetch(`${SUPABASE_URL}/storage/v1/object/sign/exports/${fileName}`, {
      method: "POST",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ expiresIn: 60 * 5 }), // 5 minutes
    });
    if (!sign.ok) throw new Error(`sign ${sign.status} ${await sign.text()}`);
    const signed = await sign.json();

    await fetch(`${SUPABASE_URL}/rest/v1/export_jobs?id=eq.${job_id}`, {
      method: "PATCH",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ status: "completed", artifact_url: signed.signedUrl, updated_at: new Date().toISOString() }),
    });

    await metricsAdd("csv_export_completed_total", { kind: "risk_corridors" }, 1);
    return new Response("ok", { status: 200 });
  } catch (e) {
    // DLQ write
    try {
      const { job_id } = await req.json().catch(() => ({ job_id: null }));
      if (job_id) {
        const jr = await fetch(`${SUPABASE_URL}/rest/v1/export_jobs?id=eq.${job_id}&select=id,org_id,params`, {
          headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
        });
        const jArr = await jr.json().catch(() => []);
        const job = jArr?.[0];
        await fetch(`${SUPABASE_URL}/rest/v1/export_jobs?id=eq.${job_id}`, {
          method: "PATCH",
          headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify({ status: "failed", error: String(e), updated_at: new Date().toISOString() }),
        });
        if (job) {
          await fetch(`${SUPABASE_URL}/rest/v1/export_dlq`, {
            method: "POST",
            headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
            body: JSON.stringify([{ kind: "risk_corridors_csv", org_id: job.org_id, payload: job.params, error: String(e) }]),
          });
        }
      }
    } catch {}
    return new Response("error", { status: 500 });
  }
});
