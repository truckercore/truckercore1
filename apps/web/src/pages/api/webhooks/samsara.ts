// apps/web/src/pages/api/webhooks/samsara.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { validateSignature, ensureIdempotent } from "../../../lib/integrations/sdk";

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
  if (req.method !== "POST") return res.status(405).end("Method Not Allowed");

  const secret = process.env.SAMSARA_WEBHOOK_SECRET!;
  const raw = await readRawBody(req);
  const sig = (req.headers["x-samsara-signature"] as string | undefined) ?? null;
  if (!validateSignature(raw, sig, secret)) return res.status(400).send("Invalid signature");

  const evt = JSON.parse(raw);
  const orgId = (evt?.metadata?.org_id as string) || (req.headers["x-app-org-id"] as string);
  if (!orgId) return res.status(400).send("Missing org_id");

  const idempKey = evt?.id || `${evt?.type}:${evt?.timestamp}`;
  const ok = await ensureIdempotent(`samsara-webhook-${orgId}-${idempKey}`, "samsara", orgId);
  if (!ok) return res.status(200).send("duplicate");

  // TODO: Map payload to positions/drivers/vehicles. For now acknowledge.
  return res.status(200).send("ok");
}
