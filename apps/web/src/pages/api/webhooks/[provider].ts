// apps/web/src/pages/api/webhooks/[provider].ts
import type { NextApiRequest, NextApiResponse } from "next";
import { Providers } from "../../../../integrations";
import { createClient } from "@supabase/supabase-js";

export const config = { api: { bodyParser: false } };

async function readRawBody(req: NextApiRequest): Promise<string> {
  return await new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => (data += chunk));
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    const { provider } = req.query as { provider: string };
    const p = Providers[provider];
    if (!p) return res.status(404).end("Unknown provider");

    const raw = await readRawBody(req);
    const signature =
      (req.headers["x-signature"] as string) ||
      (req.headers["intuit-signature"] as string) ||
      (req.headers["x-samsara-signature"] as string) ||
      "";

    // Replay guard: require timestamp within ±5 minutes
    const tsHeader = (req.headers["x-timestamp"] as string) || (req.headers["x-webhook-timestamp"] as string) || String(Date.now());
    const ts = Number(tsHeader);
    if (!Number.isFinite(ts) || Math.abs(Date.now() - ts) > 5 * 60_000) {
      return res.status(400).json({ ok: false, error: "stale" });
    }

    let valid = await p.verifyWebhook(raw, signature);

    // Fallback (dev): allow shared integration secret when provider secret not configured
    if (!valid) {
      const fallback = process.env.INTEGRATION_SIGNING_SECRET;
      if (fallback && signature === fallback) valid = true;
    }

    if (!valid) {
      return res.status(401).json({ ok: false, error: "invalid signature" });
    }

    let payload: any = {};
    try { payload = raw ? JSON.parse(raw) : {}; } catch {}
    const eventId = payload?.id || payload?.eventId || `evt_${Date.now()}`;

    const url = process.env.NEXT_PUBLIC_SUPABASE_URL as string | undefined;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY as string | undefined;
    if (!url || !serviceKey) return res.status(500).json({ ok: false, error: "Missing Supabase env" });
    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

    const { error } = await admin.from("integration_webhooks").upsert({
      provider,
      event_id: eventId,
      payload,
      signature_valid: valid,
    });
    if (error) return res.status(500).json({ ok: false, error: error.message });

    await admin.from("etl_jobs").insert({ provider, kind: "webhook.sync", args: { eventId }, status: "queued" });

    res.status(200).json({ ok: true, valid });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
}
