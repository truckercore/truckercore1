import type { NextApiRequest, NextApiResponse } from "next";
import Stripe from "stripe";
import { createClient } from "@supabase/supabase-js";
import { recordWebhookReceived, markWebhookProcessed, markWebhookErrored } from "@/server/webhooks/idempotency";
import { acquireLock } from "@/server/locks";

export const config = { api: { bodyParser: false } };

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: "2024-06-20" });

async function rawBody(req: NextApiRequest) {
  const chunks: Uint8Array[] = [];
  for await (const c of req as any) chunks.push(c as Uint8Array);
  return Buffer.concat(chunks);
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).end();

  const sig = req.headers["stripe-signature"] as string;
  const buf = await rawBody(req);

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(buf, sig, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch {
    return res.status(400).json({ ok: false, error: "invalid_signature" });
  }

  const obj = event.data.object as any;
  const orgId = obj?.metadata?.orgId || obj?.client_reference_id || null;
  const plan = obj?.items?.data?.[0]?.plan?.product || obj?.metadata?.plan || undefined;

  const rec = await recordWebhookReceived("stripe", event.id, event.type, obj, orgId ?? undefined);
  if ((rec as any).kind === "duplicate") return res.status(200).json({ ok: true, deduped: true });
  if ((rec as any).kind === "error") return res.status(500).json({ ok: false, error: (rec as any).error });

  const lockKey = orgId ? `stripe_org_${orgId}` : `stripe_evt_${event.id}`;
  const lock = await acquireLock(lockKey, 30_000);

  const supa = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

  try {
    switch (event.type) {
      case "customer.subscription.created":
      case "customer.subscription.updated":
      case "customer.subscription.resumed":
      case "checkout.session.completed": {
        if (orgId) {
          await supa.from("org_license_events").insert({
            org_id: orgId,
            source: "stripe",
            action: "activate",
            meta: { event: event.type, plan: plan ?? null, sub_id: (obj as any)?.id ?? null },
          } as any);
          await supa
            .from("orgs")
            .update({
              app_is_premium: true,
              license_status: "active",
              ...(plan ? { plan } : {}),
            } as any)
            .eq("id", orgId);
        }
        break;
      }
      case "customer.subscription.paused":
      case "customer.subscription.deleted":
      case "invoice.payment_failed": {
        if (orgId) {
          await supa.from("org_license_events").insert({
            org_id: orgId,
            source: "stripe",
            action: "deactivate",
            meta: { event: event.type, sub_id: (obj as any)?.id ?? null },
          } as any);
          await supa
            .from("orgs")
            .update({ app_is_premium: false, license_status: "inactive" } as any)
            .eq("id", orgId);
        }
        break;
      }
      default:
        break;
    }

    await markWebhookProcessed((rec as any).id);
    if (lock) await lock.release();
    return res.status(200).json({ ok: true });
  } catch (e: any) {
    await markWebhookErrored((rec as any).id, e);
    if (lock) await lock.release();
    return res.status(202).json({ ok: false, queued: false, error: String(e) });
  }
}
