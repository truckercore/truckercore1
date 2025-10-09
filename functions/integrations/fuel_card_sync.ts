import { serve } from "std/server";
import { fetchFuelCardData } from "../lib/external_fuel_api.ts";
import { insertFuelTransactions } from "../lib/supabase_client.ts";
import { makeRequestId, ok, error as errResp } from "../lib/http.ts";
import { auditInsert } from "../lib/audit.ts";

// Edge Function: External Integration Connector (Fuel Card)
// Deploy: supabase functions deploy fuel-card-sync --no-verify-jwt
// Invoke: supabase functions invoke fuel-card-sync

serve(async (req) => {
  const request_id = makeRequestId(req);
  const started = Date.now();
  try {
    const data = await fetchFuelCardData();
    const inserted = await insertFuelTransactions(data);
    const latency_ms = Date.now() - started;
    await auditInsert("edge.fuel_card_sync", "import", { inserted, latency_ms }, request_id, 0.25);
    return ok({ inserted, latency_ms }, request_id);
  } catch (err) {
    console.error("fuel_card_sync error", request_id, err);
    return errResp(String(err), request_id, 500);
  }
});
