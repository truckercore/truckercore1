// supabase/functions/outbox_consumer/index.ts
// Minimal worker that processes one pending outbox row per invocation.
// Assumes service role. Keep handlers tiny and safe.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type OutboxRow = {
  id: string;
  scope: string;
  idempotency_key: string;
  payload: any;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

// Handlers per scope — add more as you need
async function handleOfferRequest(row: OutboxRow) {
  // payload example: { load_id, message, from_user_id?, driver_id? }
  const p = row.payload || {};
  if (!p.load_id) throw new Error("Missing load_id");

  // Insert an offer/request into your marketplace_offers (or broker_requests) table
  const { error } = await sb.from("marketplace_offers").insert({
    load_id: p.load_id,
    carrier_id: p.carrier_id ?? null,
    driver_id: p.driver_id ?? null,
    bid_usd: p.bid_usd ?? null,
    message: p.message ?? null,
    status: "pending",
    // optional: store idempotency for audits
    idempotency_key: row.idempotency_key,
  });
  if (error) throw error;
}

async function handleDriverAssign(row: OutboxRow) {
  // payload example: { load_id, driver_id }
  const p = row.payload || {};
  if (!p.load_id || !p.driver_id) throw new Error("Missing load_id/driver_id");

  // Update loads.assigned_driver_id safely
  const { error } = await sb.from("loads")
    .update({ assigned_driver_id: p.driver_id })
    .eq("id", p.load_id);
  if (error) throw error;
}

async function handleSafetyAck(row: OutboxRow) {
  // payload example: { incident_id, ack_user_id }
  const p = row.payload || {};
  if (!p.incident_id) throw new Error("Missing incident_id");
  const { error } = await sb.from("safety_coaching").insert({
    incident_id: p.incident_id,
    coach_user_id: p.ack_user_id ?? null,
    note: p.note ?? "Acknowledged",
  });
  if (error) throw error;
}

async function route(row: OutboxRow) {
  switch (row.scope) {
    case "offer_request":   return handleOfferRequest(row);
    case "driver_assign":   return handleDriverAssign(row);
    case "safety_ack":      return handleSafetyAck(row);
    default: throw new Error(`Unknown scope: ${row.scope}`);
  }
}

Deno.serve(async () => {
  // 1) pick next pending row (one at a time)
  const { data: row, error: selErr } = await sb.rpc("dequeue_outbox_one"); // see SQL below
  if (selErr) return new Response(JSON.stringify({ ok:false, error: selErr.message }), { status: 500 });
  if (!row) return new Response(JSON.stringify({ ok:true, processed:0 }), { status: 200 });

  const outbox = row as OutboxRow;

  try {
    // 2) do work
    await route(outbox);

    // 3) mark done and reset attempts
    const { error: updErr } = await sb.from("action_outbox")
      .update({ status: "done", processed_at: new Date().toISOString(), error: null })
      .eq("id", outbox.id);
    if (updErr) throw updErr;

    return new Response(JSON.stringify({ ok:true, processed:1, id: outbox.id }), { status: 200 });
  } catch (e: any) {
    // Increment attempts and dead-letter after 3 tries
    const { data: cur } = await sb.from("action_outbox").select("attempts").eq("id", outbox.id).single();
    const attempts = (cur?.attempts ?? 0) + 1;
    if (attempts >= 3) {
      await sb.from("action_outbox")
        .update({ status: "dead", attempts, error: String(e?.message ?? e), processed_at: new Date().toISOString() })
        .eq("id", outbox.id);
    } else {
      await sb.from("action_outbox")
        .update({ status: "failed", attempts, error: String(e?.message ?? e) })
        .eq("id", outbox.id);
    }
    return new Response(JSON.stringify({ ok:false, id: outbox.id, error: String(e?.message ?? e) }), { status: 500 });
  }
});
