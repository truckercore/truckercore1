import { NextResponse } from "next/server";
import Stripe from "stripe";
import { createClient } from "@supabase/supabase-js";
import { recordWebhookReceived, markWebhookProcessed, markWebhookErrored } from "@/server/webhooks/idempotency";
import { acquireLock } from "@/server/locks";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  const secret = process.env.STRIPE_WEBHOOK_SECRET!;
  const stripeSecret = process.env.STRIPE_SECRET_KEY!;
  if (!secret || !stripeSecret) return NextResponse.json({ ok: false, error: "missing_env" }, { status: 500 });

  const stripe = new Stripe(stripeSecret, { apiVersion: "2024-06-20" });

  const sig = req.headers.get("stripe-signature") as string;
  const buf = new Uint8Array(await req.arrayBuffer());

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(buf, sig, secret);
  } catch {
    return NextResponse.json({ ok: false, error: "invalid_signature" }, { status: 400 });
  }

  const obj: any = (event as any).data.object;
  const orgId = obj?.metadata?.orgId || obj?.client_reference_id || null;
  const plan = obj?.items?.data?.[0]?.plan?.product || obj?.metadata?.plan || undefined;

  const rec = await recordWebhookReceived("stripe", event.id, event.type, obj, orgId ?? undefined);
  if (rec.kind === "duplicate") return NextResponse.json({ ok: true, deduped: true }, { status: 200 });
  if (rec.kind === "error") return NextResponse.json({ ok: false, error: rec.error }, { status: 500 });

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

    await markWebhookProcessed(rec.id);
    if (lock) await lock.release();
    return NextResponse.json({ ok: true }, { status: 200 });
  } catch (e) {
    await markWebhookErrored(rec.id, e);
    if (lock) await lock.release();
    return NextResponse.json({ ok: false, queued: false, error: String(e) }, { status: 202 });
  }
}
