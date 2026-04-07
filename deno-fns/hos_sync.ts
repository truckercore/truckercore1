// deno-fns/hos_sync.ts
// Nightly HOS/ELD sync skeleton. Iterates provider tokens, fetches provider APIs (stub),
// upserts normalized duty status and violations, and logs ingest to hos_sync_log.
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE");
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE");
}
const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

async function fakeFetchProvider(provider_key: string, token: string) {
  // Placeholder: simulate a couple of duty segments and a possible violation
  await new Promise((r) => setTimeout(r, 50));
  const now = Date.now();
  return {
    duty: [
      { started_at: new Date(now - 3*3600_000).toISOString(), ended_at: new Date(now - 2*3600_000).toISOString(), status: "on" },
      { started_at: new Date(now - 2*3600_000).toISOString(), ended_at: new Date(now - 1*3600_000).toISOString(), status: "dr" },
      { started_at: new Date(now - 1*3600_000).toISOString(), ended_at: null, status: "on" },
    ],
    violations: [
      { occurred_at: new Date(now - 30*60_000).toISOString(), kind: "30m_break", severity: "minor" },
    ],
  } as const;
}

Deno.serve(async () => {
  const t0 = performance.now();
  // Load tokens
  const { data: tokens, error } = await db.from("hos_provider_tokens").select("id, provider_key, access_token");
  if (error) return new Response(error.message, { status: 500 });

  const tasks = (tokens ?? []).map(async (t) => {
    const tStart = performance.now();
    let rowsDuty = 0, rowsViol = 0, ok = true, lastError: string | null = null;
    try {
      const payload = await fakeFetchProvider(t.provider_key, t.access_token);
      // Upsert duty
      for (const d of payload.duty) {
        const row = {
          provider_key: t.provider_key,
          driver_id: crypto.randomUUID(), // TODO map provider driver -> internal driver
          started_at: d.started_at,
          ended_at: d.ended_at,
          status: d.status,
          location: null,
          meta: {},
        };
        const { error: e1 } = await db.from("hos_duty_status").insert(row);
        if (!e1) rowsDuty++; else console.error("hos duty insert", e1.message);
      }
      // Upsert violations
      for (const v of payload.violations) {
        const row = {
          provider_key: t.provider_key,
          driver_id: crypto.randomUUID(), // TODO mapping
          occurred_at: v.occurred_at,
          kind: v.kind,
          severity: v.severity,
          meta: {},
        };
        const { error: e2 } = await db.from("hos_violations").insert(row);
        if (!e2) rowsViol++; else console.error("hos viol insert", e2.message);
      }
      await db.from("hos_provider_tokens").update({ last_success_at: new Date().toISOString(), last_error: null }).eq("id", t.id);
    } catch (e) {
      ok = false; lastError = (e as Error).message;
      await db.from("hos_provider_tokens").update({ last_error: lastError }).eq("id", t.id);
    } finally {
      const duration_ms = Math.round(performance.now() - tStart);
      await db.from("hos_sync_log").insert({
        provider_key: t.provider_key,
        token_id: t.id,
        ok,
        rows_duty: rowsDuty,
        rows_viol: rowsViol,
        duration_ms,
        meta: lastError ? { error: lastError } : {},
      });
    }
  });

  await Promise.allSettled(tasks);
  const t1 = performance.now();
  return new Response(JSON.stringify({ ok: true, duration_ms: Math.round(t1 - t0), tokens: tokens?.length ?? 0 }), { headers: { "content-type": "application/json" } });
});
