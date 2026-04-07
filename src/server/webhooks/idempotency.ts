// src/server/webhooks/idempotency.ts
// Idempotent audit helper for webhook processing via Supabase
import { createClient } from "@supabase/supabase-js";

export type IdempotencyResult =
  | { kind: "new"; id: string }
  | { kind: "duplicate"; id: string }
  | { kind: "error"; id?: string; error: string };

function srv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL as string | undefined;
  const key =
    (process.env.SUPABASE_SERVICE_ROLE_KEY as string | undefined) ||
    (process.env.SUPABASE_SERVICE_ROLE as string | undefined) ||
    (process.env.SUPABASE_SERVICE_KEY as string | undefined);
  if (!url || !key) throw new Error("Supabase service env missing");
  return createClient(url, key, { auth: { persistSession: false } });
}

export async function recordWebhookReceived(
  provider: string,
  eventId: string,
  eventType: string,
  payload: unknown,
  orgId?: string | null
): Promise<IdempotencyResult> {
  const supa = srv();

  // Attempt insert; allow PostgREST "Prefer: resolution=merge-duplicates"-like behavior via RPC not available in JS client.
  const { data, error } = await supa
    .from("webhook_events")
    .insert(
      {
        provider,
        event_id: eventId,
        event_type: eventType,
        payload,
        org_id: orgId ?? null,
        status: "received",
      } as any,
      { returning: "representation", count: "exact" }
    )
    .select("id")
    .single();

  if (!error && data) return { kind: "new", id: (data as any).id };

  const msg = String(error?.message || "");
  if (msg.includes("duplicate") || msg.includes("already exists") || (error as any)?.code === "23505") {
    const { data: existing } = await supa
      .from("webhook_events")
      .select("id")
      .eq("provider", provider)
      .eq("event_id", eventId)
      .maybeSingle();
    return { kind: "duplicate", id: (existing as any)?.id ?? "" };
  }

  return { kind: "error", error: msg || "unknown_error" };
}

export async function markWebhookProcessed(auditId: string) {
  const supa = srv();
  await supa.from("webhook_events").update({ status: "processed" }).eq("id", auditId);
}

export async function markWebhookErrored(auditId: string, err: unknown) {
  const supa = srv();
  await supa
    .from("webhook_events")
    .update({ status: "errored", error: String(err) })
    .eq("id", auditId);
}
