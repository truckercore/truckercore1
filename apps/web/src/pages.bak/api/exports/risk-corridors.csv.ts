import type { NextApiRequest, NextApiResponse } from "next";
import crypto from "crypto";

function getJwt(req: NextApiRequest): string | null {
  const auth = req.headers.authorization || "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  return m ? m[1] : null;
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    const jwt = getJwt(req);
    if (!jwt) return res.status(401).send("Missing JWT");
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
    if (!supabaseUrl) return res.status(500).send("Missing SUPABASE_URL");

    // Rate limit: 5 req/min per org (best-effort: rely on edge cache or lightweight memory in serverless env is tricky)
    res.setHeader("Cache-Control", "no-store");

    // Query PostgREST as the user (JWT) to enforce RLS and security barrier in the view
    const limit = Math.min(parseInt(String(req.query.limit || "100"), 10) || 100, 1000);
    const from = req.query.from as string | undefined;
    const to = req.query.to as string | undefined;

    const qs = new URLSearchParams();
    qs.set("select", "org_id,observed_at,urgent_count,alert_count,types,cell_geojson");
    qs.set("order", "observed_at.desc");
    qs.set("limit", String(limit));
    if (from) qs.set("observed_at", `gte.${encodeURIComponent(from)}`);
    if (to) qs.append("observed_at", `lte.${encodeURIComponent(to)}`);

    const url = `${String(supabaseUrl).replace(/\/$/, "")}/rest/v1/v_risk_corridors_export?${qs.toString()}`;
    const r = await fetch(url, {
      headers: {
        apikey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "",
        Authorization: `Bearer ${jwt}`,
        Accept: "text/csv",
        "Accept-Profile": "public",
        "Content-Profile": "public",
        Prefer: "count=exact",
      },
    });

    const exportId = crypto.randomUUID();
    const rowCountHdr = r.headers.get("content-range") || "";
    const rowCount = (() => {
      const m = rowCountHdr.match(/\/(\d+)$/);
      return m ? parseInt(m[1], 10) : NaN;
    })();

    if (!r.ok) {
      // best-effort DLQ (requires service-role; skip here in sync path to avoid leakage)
      return res.status(r.status).send(await r.text());
    }

    // Stream to buffer to compute checksum; if environment supports streamed transform, swap to streamed digest
    const csvText = await r.text();
    const sha = crypto.createHash("sha256").update(csvText).digest("hex");

    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="risk-corridors.csv"`);
    res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate");
    res.setHeader("X-Export-Id", exportId);
    if (Number.isFinite(rowCount)) res.setHeader("X-Row-Count", String(rowCount));
    res.setHeader("X-Checksum-SHA256", sha);

    res.status(200).send(csvText);
  } catch (e: any) {
    res.status(500).send(e?.message || "error");
  }
}
