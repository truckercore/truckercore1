// supabase/functions/_shared/metrics.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const url = Deno.env.get('SUPABASE_URL')!;
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const cli = createClient(url, key);

export async function record(fn: string, status: 'ok'|'error', ms: number, orgId?: string, requestId?: string) {
  await cli.from('function_invocations').insert({ fn, status, ms, org_id: orgId ?? null, request_id: requestId ?? null });
}

export async function withMetrics<T>(fnName: string, f: () => Promise<T>, orgId?: string, requestId?: string): Promise<T> {
  const t0 = performance.now();
  try {
    const r = await f();
    await record(fnName, 'ok', Math.round(performance.now() - t0), orgId, requestId);
    return r;
  } catch (e) {
    await record(fnName, 'error', Math.round(performance.now() - t0), orgId, requestId);
    throw e;
  }
}
