import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { maybeFail } from "../_shared/fault.ts";
import { withMetrics } from "../_shared/metrics.ts";
import { withApiShape, ok, err } from "../_shared/http.ts";

type Plan = { departAt: string; targetSpeedMph: number; hazmat?: boolean; routeId?: string; };

serve(withApiShape((req) => withMetrics('validate_plan', async () => {
  if (req.method !== 'POST') return err('bad_request', 'Use POST', undefined, 405);
  await maybeFail();
  const p = (await req.json()) as Plan;
  const errs: string[] = [];
  if (p.targetSpeedMph > 65) errs.push("Speed exceeds safety policy");
  // TODO: check hazmat corridors, bridge DB, HOS windows...
  if (errs.length) {
    return new Response(JSON.stringify({ status: 'error', code: 'bad_request', message: 'Validation failed', errors: errs }), { status: 422, headers: { "content-type": "application/json" } });
  }
  return ok({ ok: true });
})));
