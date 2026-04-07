import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const jobId = req.query.jobId as string;
  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;
  const jwt = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (!supabaseUrl || !serviceKey || !jwt) return res.status(500).send("Server not configured");

  const url = new URL(`${supabaseUrl!.replace(/\/$/, "")}/rest/v1/export_jobs`);
  url.searchParams.set("id", `eq.${jobId}`);
  url.searchParams.set("select", "id,org_id,kind,status,artifact_url,error,created_at,updated_at");

  const r = await fetch(url.toString(), {
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
    },
  });
  if (!r.ok) return res.status(r.status).send(await r.text());
  const arr = await r.json();
  const job = Array.isArray(arr) ? arr[0] : null;
  if (!job) return res.status(404).send("Not found");

  // Return short-lived signed URL as artifact when completed
  return res.status(200).json({
    id: job.id,
    status: job.status,
    artifact_url: job.artifact_url || null,
    error: job.error || null,
    created_at: job.created_at,
    updated_at: job.updated_at,
  });
}
