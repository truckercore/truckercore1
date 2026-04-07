// Supabase Edge Function: Offline Replay (idempotent, backoff, quarantine)
// Path: supabase/functions/offline_replay/index.ts
// Invoke via schedule: every 1–5 minutes
// Behavior: Replays pending/failed mobile offline operations with dedupe protection,
//           exponential backoff, basic concurrency control, and quarantine for malformed ops.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// Types for clarity
type OfflineOp = {
  id: string;
  user_id: string;
  op_type: string;
  payload: any;
  dedupe_key?: string | null;
  status: "pending" | "processing" | "success" | "failed";
  attempt_count?: number | null;
  next_attempt_at?: string | null;
  created_at?: string;
};

// Determine whether an error indicates a malformed payload that should be quarantined
function isMalformedError(e: unknown, op: OfflineOp): boolean {
  const msg = String(e || "").toLowerCase();
  if (!op?.op_type) return true;
  if (msg.includes("unknown op_type") || msg.includes("malformed") || msg.includes("validation")) return true;
  // If payload is not an object for ops that require it
  if (["request_load", "save_item", "follow_up"].includes(op.op_type) && (op as any)?.payload == null) return true;
  return false;
}

// Map op_type to handlers (implement business logic as needed)
async function handleOp(sb: any, op: OfflineOp) {
  switch (op.op_type) {
    case "request_load": {
      // Example: call an existing propose/request endpoint or function
      // await fetch(`${Deno.env.get("BASE_URL")}/functions/v1/request_load`, { method: "POST", body: JSON.stringify(op.payload) });
      return; // no-op placeholder
    }
    case "save_item": {
      // Example: upsert saved item
      // await sb.from("saved_items").upsert({ user_id: op.user_id, ...op.payload });
      return; // no-op placeholder
    }
    case "follow_up": {
      // Example: call follow-up endpoint
      // await fetch(`${Deno.env.get("BASE_URL")}/functions/v1/follow_up`, { method: "POST", body: JSON.stringify(op.payload) });
      return; // no-op placeholder
    }
    default:
      throw new Error(`unknown op_type: ${op.op_type}`);
  }
}

serve(async (req) => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false }, global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );

  // Pull a small batch of eligible ops (oldest first): pending or failed with next_attempt_at <= now
  const nowIso = new Date().toISOString();
  const { data: ops, error } = await sb
    .from("mobile_offline_queue")
    .select("*")
    .in("status", ["pending", "failed"])
    .or(`next_attempt_at.is.null,next_attempt_at.lte.${nowIso}`)
    .order("created_at", { ascending: true })
    .limit(100);

  if (error) {
    return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });
  }

  let success = 0, failed = 0, quarantined = 0, skipped = 0;

  for (const raw of ops ?? []) {
    const op = raw as OfflineOp;

    // Concurrency guard: attempt to lock the row by setting status=processing if still eligible
    const lock = await sb.from("mobile_offline_queue").update({ status: "processing" })
      .eq("id", op.id)
      .in("status", ["pending", "failed"]) // still not taken
      .or(`next_attempt_at.is.null,next_attempt_at.lte.${nowIso}`)
      .select("id")
      .maybeSingle();
    if (!lock.data) { skipped++; continue; }

    try {
      // Recheck idempotency: if dedupe_key already succeeded for this user, mark success and skip
      if (op.dedupe_key) {
        const already = await sb
          .from("mobile_offline_queue")
          .select("id")
          .eq("user_id", op.user_id)
          .eq("dedupe_key", op.dedupe_key)
          .eq("status", "success")
          .maybeSingle();
        if (already.data) {
          await sb.from("mobile_offline_queue")
            .update({ status: "success", replayed_at: new Date().toISOString() })
            .eq("id", op.id);
          success++;
          continue;
        }
      }

      await handleOp(sb, op);

      await sb.from("mobile_offline_queue")
        .update({ status: "success", replayed_at: new Date().toISOString(), attempt_count: (op.attempt_count ?? 0) })
        .eq("id", op.id);
      success++;
    } catch (e) {
      // Determine quarantine vs retry with backoff
      if (isMalformedError(e, op)) {
        // Quarantine malformed ops and remove from main queue
        try {
          await sb.from("offline_quarantine").insert({
            op_id: op.id,
            user_id: op.user_id,
            op_type: op.op_type,
            payload: op.payload,
            dedupe_key: op.dedupe_key ?? null,
            error_text: String(e),
            quarantined_at: new Date().toISOString(),
          });
        } catch (_) { /* ignore */ }
        await sb.from("mobile_offline_queue").delete().eq("id", op.id);
        quarantined++;
      } else {
        const attempts = (op.attempt_count ?? 0) + 1;
        const base = 30; // seconds
        const maxBackoff = 15 * 60; // 15 minutes cap
        const backoffSec = Math.min(maxBackoff, Math.floor(base * Math.pow(2, attempts - 1)));
        const next = new Date(Date.now() + backoffSec * 1000).toISOString();
        await sb.from("mobile_offline_queue").update({
          status: "failed",
          attempt_count: attempts,
          next_attempt_at: next,
        }).eq("id", op.id);
        failed++;
      }
    }
  }

  return new Response(JSON.stringify({ ok: true, success, failed, quarantined, skipped }), { status: 200 });
});
