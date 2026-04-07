import type { NextApiRequest, NextApiResponse } from "next";
import crypto from "crypto";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL as string;
    const serviceKey = (process.env.SUPABASE_SERVICE_ROLE as string | undefined) || (process.env.SUPABASE_SERVICE_ROLE_KEY as string | undefined);
    if (!supabaseUrl) return res.status(500).send("Missing NEXT_PUBLIC_SUPABASE_URL");
    if (!serviceKey) return res.status(500).send("Missing service role key");

    const orgId = (req.headers["x-app-org-id"] as string | undefined) || (req.query.org_id as string | undefined) || "";
    const qs = new URLSearchParams();
    if (orgId) qs.set("org_id", `eq.${orgId}`);

    const url = `${supabaseUrl.replace(/\/$/, "")}/rest/v1/alerts_export_masked?${qs.toString()}`;
    const r = await fetch(url, {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        Accept: "text/csv",
        "Content-Profile": "public",
      },
    });

    if (!r.ok) {
      const txt = await r.text();
      return res.status(r.status).send(txt);
    }

    const csv = await r.text();
    const sha = crypto.createHash("sha256").update(csv, "utf8").digest("hex");
    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", 'attachment; filename="alerts.csv"');
    res.setHeader("Cache-Control", "private, max-age=0, no-store");
    res.setHeader("X-Robots-Tag", "noindex");
    res.setHeader("X-Content-SHA256", sha);
    return res.status(200).send(csv);
  } catch (e: any) {
    return res.status(500).send(String(e?.message || e));
  }
}
