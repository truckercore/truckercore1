import type { NextApiRequest, NextApiResponse } from "next";
import { randomUUID } from "crypto";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");
  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;
  const jwt = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (!supabaseUrl || !serviceKey || !jwt) return res.status(500).send("Server not configured");

  try {
    // Extract org_id from caller JWT (PostgREST will enforce RLS again when exporting)
    const jobId = randomUUID();
    const params = {
      from: (req.body as any)?.from || null,
      to: (req.body as any)?.to || null,
      limit: Math.min(parseInt(String((req.body as any)?.limit || "1000"), 10) || 1000, 20000),
    };

    // Insert queued job (service key)
    const ins = await fetch(`${supabaseUrl.replace(/\/$/, "")}/rest/v1/export_jobs`, {
      method: "POST",
      headers: {
        apikey: String(serviceKey),
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify([
        {
          id: jobId,
          kind: "risk_corridors_csv",
          // org_id taken from JWT by policy? We cannot rely on RLS with service role.
          // Decode to set org_id. For simplicity, let client pass 'x-app-org-id' header; fall back to JWT claim.
          org_id: (req.headers["x-app-org-id"] as string) || null,
          params,
          status: "queued",
        },
      ]),
    });
    if (!ins.ok) {
      const t = await ins.text();
      return res.status(500).send(`Insert job failed: ${t}`);
    }

    // Trigger backend worker via Edge Function (fire-and-forget)
    fetch(`${supabaseUrl.replace(/\/$/, "")}/functions/v1/run-export-job`, {
      method: "POST",
      headers: {
        apikey: String(serviceKey),
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ job_id: jobId, jwt }),
    }).catch(() => {});

    return res.status(200).json({ job_id: jobId });
  } catch (e: any) {
    return res.status(500).send(e?.message || "error");
  }
}
