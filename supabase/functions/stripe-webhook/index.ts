// Deno Edge Function: Stripe webhook (verified + idempotent)
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@14.25.0?target=deno&deno-std=0.224.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
  Deno.env.get("SUPABASE_SERVICE_ROLE") ||
  Deno.env.get("SUPABASE_SERVICE_KEY")!;
const STRIPE_SECRET = Deno.env.get("STRIPE_SECRET_KEY")!;
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

async function supabaseFetch(path: string, init: RequestInit = {}) {
  const url = `${SUPABASE_URL.replace(/\/$/, "")}${path}`;
  const headers = new Headers(init.headers || {});
  headers.set("apikey", SERVICE_KEY);
  headers.set("Authorization", `Bearer ${SERVICE_KEY}`);
  return fetch(url, { ...init, headers });
}

async function recordReceived(provider: string, eventId: string, eventType: string, payload: unknown, orgId?: string | null) {
  const res = await supabaseFetch(`/rest/v1/webhook_events`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify({
      provider,
      event_id: eventId,
      event_type: eventType,
      payload,
      org_id: orgId ?? null,
      status: "received",
    }),
  });
  if (res.ok) {
    const j = await res.json().catch(() => []);
    const id = Array.isArray(j) && (j as any)[0]?.id ? (j as any)[0].id : (j as any)?.id;
    return { kind: "new", id: id as string } as const;
  }
  const text = await res.text();
  if (text.includes("duplicate") || res.status === 409) {
    const q = new URLSearchParams();
    q.set("select", "id");
    q.set("provider", `eq.${provider}`);
    q.set("event_id", `eq.${eventId}`);
    const ex = await supabaseFetch(`/rest/v1/webhook_events?${q.toString()}`);
    const arr = await ex.json().catch(() => []);
    return { kind: "duplicate", id: (arr as any)?.[0]?.id ?? "" } as const;
  }
  return { kind: "error", error: text } as const;
}

async function markProcessed(id: string) {
  await supabaseFetch(`/rest/v1/webhook_events?id=eq.${encodeURIComponent(id)}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ status: "processed" }),
  });
}
async function markErrored(id: string, err: unknown) {
  await supabaseFetch(`/rest/v1/webhook_events?id=eq.${encodeURIComponent(id)}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ status: "errored", error: String(err) }),
  });
}

const stripe = new Stripe(STRIPE_SECRET, { apiVersion: "2024-06-20" });

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  const sig = req.headers.get("stripe-signature")!;
  const buf = new Uint8Array(await req.arrayBuffer());

  let event: any;
  try {
    event = await stripe.webhooks.constructEventAsync(buf, sig, STRIPE_WEBHOOK_SECRET);
  } catch {
    return new Response(JSON.stringify({ ok: false, error: "invalid_signature" }), { status: 400 });
  }

  const obj: any = event.data.object;
  const orgId = obj?.metadata?.orgId || obj?.client_reference_id || null;
  const plan = obj?.items?.data?.[0]?.plan?.product || obj?.metadata?.plan || undefined;

  const rec: any = await recordReceived("stripe", event.id, event.type, obj, orgId ?? undefined);
  if (rec.kind === "duplicate") return new Response(JSON.stringify({ ok: true, deduped: true }), { status: 200 });
  if (rec.kind === "error") return new Response(JSON.stringify({ ok: false, error: rec.error }), { status: 500 });

  try {
    switch (event.type) {
      case "customer.subscription.created":
      case "customer.subscription.updated":
      case "customer.subscription.resumed":
      case "checkout.session.completed":
        if (orgId) {
          await supabaseFetch(`/rest/v1/org_license_events`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              org_id: orgId,
              source: "stripe",
              action: "activate",
              meta: { event: event.type, plan: plan ?? null, sub_id: obj?.id ?? null },
            }),
          });
          await supabaseFetch(`/rest/v1/orgs?id=eq.${encodeURIComponent(orgId)}`, {
            method: "PATCH",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ app_is_premium: true, license_status: "active", ...(plan ? { plan } : {}) }),
          });
        }
        break;
      case "customer.subscription.paused":
      case "customer.subscription.deleted":
      case "invoice.payment_failed":
        if (orgId) {
          await supabaseFetch(`/rest/v1/org_license_events`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              org_id: orgId,
              source: "stripe",
              action: "deactivate",
              meta: { event: event.type, sub_id: obj?.id ?? null },
            }),
          });
          await supabaseFetch(`/rest/v1/orgs?id=eq.${encodeURIComponent(orgId)}`, {
            method: "PATCH",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ app_is_premium: false, license_status: "inactive" }),
          });
        }
        break;
      default:
        break;
    }

    await markProcessed(rec.id);
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    await markErrored(rec.id, e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 202 });
  }
});