// Supabase Edge Function: synthetic_load
// Path: supabase/functions/synthetic_load/index.ts
// Purpose: Generate synthetic HOS duty logs for testing dashboards and summaries.
//
// Usage examples:
//   Generate load (caps and defaults applied):
//     GET /functions/v1/synthetic_load?drivers=1000&hours=48&chunk=5000&org=<org-uuid>
//
//   After generating, you can summarize via SQL helpers (if present in your DB):
//     select public.summarize_hos_daily(current_date - 1);
//     select public.summarize_hos_daily_range(current_date - 7, current_date - 1);
//     select public.prune_old_payloads();
//     select public.raise_alarm_if_overload();
//
// Notes:
// - This function uses the service role; keep it protected (require service-role bearer when invoking externally).
// - Inserts are chunked to avoid oversized payloads/timeouts.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

// Early environment validation
const required = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
];
const missing = required.filter((k) => !Deno.env.get(k));
if (missing.length) {
  console.error(`[startup] Missing required envs: ${missing.join(', ')}`);
  throw new Error('Configuration error: missing required environment variables');
}
const svc = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
if (!/^([A-Za-z0-9\.\-_]{20,})$/.test(svc)) {
  console.warn('[startup] SUPABASE_SERVICE_ROLE_KEY format looks unusual');
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supa = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

// Simple integer clamp
const clamp = (n: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, n));
const rand = (min: number, max: number) => Math.floor(Math.random() * (max - min + 1)) + min;

Deno.serve(async (req: Request) => {
  try {
    // Optional: require service role header to avoid accidental public access
    const authz = req.headers.get("authorization") || req.headers.get("Authorization");
    if (!authz || !authz.toLowerCase().startsWith("bearer ")) {
      return new Response(JSON.stringify({ ok: false, error: "AUTH_REQUIRED" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }

    const q = new URL(req.url).searchParams;
    const drivers = clamp(Number(q.get("drivers") ?? 100), 1, 5000); // cap to protect DB
    const hours = clamp(Number(q.get("hours") ?? 24), 1, 168); // up to 7 days
    const chunkSize = clamp(Number(q.get("chunk") ?? 2000), 200, 10000);
    const orgId = q.get("org") || crypto.randomUUID();

    const nowMs = Date.now();
    const rows: any[] = [];

    for (let d = 0; d < drivers; d++) {
      const driver_user_id = crypto.randomUUID();
      let t = nowMs - hours * 3600 * 1000;
      for (let i = 0; i < hours; i++) {
        const on = new Date(t);
        const off = new Date(t + rand(20, 50) * 60 * 1000);
        rows.push({
          org_id: orgId,
          driver_user_id,
          start_time: on.toISOString(),
          end_time: off.toISOString(),
          status: i % 3 === 0 ? "driving" : "on", // simple duty pattern per hour
          source: "manual",
        });
        t = off.getTime() + rand(5, 20) * 60 * 1000;
      }
    }

    // Insert in chunks to avoid payload/timeouts
    let inserted = 0;
    for (let i = 0; i < rows.length; i += chunkSize) {
      const slice = rows.slice(i, i + chunkSize);
      const { error } = await supa.from("hos_logs").insert(slice, { returning: "minimal" });
      if (error) throw error;
      inserted += slice.length;
    }

    return new Response(JSON.stringify({ ok: true, inserted }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
