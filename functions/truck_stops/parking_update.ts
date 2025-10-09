import { serve } from "std/server";
import { insertParkingSignal } from "../lib/db.ts";
import { makeRequestId, ok, badRequest, error as errResp, idempotencyKey } from "../lib/http.ts";
import { auditInsert } from "../lib/audit.ts";
import { enforceCooldown } from "../lib/rate_limit.ts";
import { metricsPush } from "../lib/metrics.ts";

// Parking Status Update (Operator-facing API)
// Deploy: supabase functions deploy parking-update --no-verify-jwt
// Invoke: supabase functions invoke parking-update -b '{"truck_stop_id":"uuid","available_spots":12,"total_spots":80,"reported_by":"operator"}'

const COOLDOWN_SECONDS = 600; // 10 minutes per device/operator submission

serve(async (req) => {
  const request_id = makeRequestId(req);
  const started = Date.now();
  try {
    const { truck_stop_id, available_spots, total_spots, reported_by, premium_details, device_hash } = await req.json();
    if (!truck_stop_id || available_spots === undefined || total_spots === undefined || !reported_by) {
      await metricsPush('parking-update', 'bad_request', { reason: 'missing_fields' }, request_id, 1.0);
      return badRequest("Missing required fields", request_id);
    }

    const deviceHashHeader = req.headers.get('X-Device-Hash') ?? req.headers.get('x-device-hash');
    const key = deviceHashHeader ?? device_hash ?? `anon-${truck_stop_id}`;
    const rl = enforceCooldown(`${reported_by}:${truck_stop_id}:${key}`, COOLDOWN_SECONDS);
    if (!rl.ok) {
      await metricsPush('parking-update', 'rate_limited', { retry_after_s: rl.retryAfter }, request_id, 1.0);
      return new Response(
        JSON.stringify({ ok: false, error: { code: 'rate_limited', message: `Cooldown active. Retry in ${rl.retryAfter}s` }, request_id }),
        { headers: { 'Content-Type': 'application/json', 'Retry-After': String(rl.retryAfter), 'x-request-id': request_id }, status: 429 },
      );
    }

    const res = await insertParkingSignal({
      truck_stop_id,
      available_spots: Number(available_spots),
      total_spots: Number(total_spots),
      reported_by,
      premium_details: premium_details ?? null,
    });

    const latency_ms = Date.now() - started;
    await auditInsert("edge.parking_update", "insert", { truck_stop_id, available_spots, total_spots, reported_by, latency_ms, idempotency: idempotencyKey(req) }, request_id, 0.25);
    await metricsPush('parking-update', 'ok', { latency_ms }, request_id, 0.25);
    return ok({ ...res, latency_ms }, request_id, { 'Idempotency-Key': idempotencyKey(req) ?? '' });
  } catch (err) {
    console.error("parking_update error", request_id, err);
    await metricsPush('parking-update', 'error', { message: String(err) }, request_id, 1.0);
    return errResp(String(err), request_id, 500);
  }
});
