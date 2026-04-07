// supabase/functions/parking-report/index.ts
// Accepts a single user parking report and rate-limits submissions per user/device per stop.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

// Early environment validation
const required = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"] as const;
const missing = required.filter((k) => !Deno.env.get(k));
if (missing.length) {
  console.error(`[startup] Missing required envs: ${missing.join(', ')}`);
  throw new Error("Configuration error: missing required environment variables");
}
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
if (!/^([A-Za-z0-9\._\-]{20,})$/.test(svc)) {
  console.warn("[startup] SUPABASE_SERVICE_ROLE_KEY format looks unusual");
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

type Claims = { sub?: string };
function parseJwt<T = Claims>(authz: string | null): T | null {
  try {
    if (!authz) return null;
    const token = authz.replace(/^Bearer\s+/i, '').trim();
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(json) as T;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'METHOD_NOT_ALLOWED' }), { status: 405, headers: { 'Content-Type': 'application/json' } });
    }

    const claims = parseJwt<Claims>(req.headers.get('Authorization'));
    const userId = claims?.sub ?? null;

    const body = await req.json().catch(() => ({})) as { stop_id?: string; kind?: string; value?: number; device_hash?: string };
    if (!body.stop_id || !body.kind) {
      return new Response(JSON.stringify({ error: "stop_id, kind required" }), { status: 400, headers: { "Content-Type": "application/json" } });
    }
    if (body.kind === "count" && (typeof body.value !== "number" || body.value < 0)) {
      return new Response(JSON.stringify({ error: "value >= 0 required when kind='count'" }), { status: 400, headers: { "Content-Type": "application/json" } });
    }

    // Rate limit: one report per user/device per stop per cooldown minutes (env override)
    const COOLDOWN_MIN = Number(Deno.env.get("PARKING_COOLDOWN_MIN") ?? "10");
    const sinceIso = new Date(Date.now() - COOLDOWN_MIN * 60 * 1000).toISOString();
    const { data: recent, error: recErr } = await supabase
      .from('parking_reports')
      .select('id')
      .eq('stop_id', body.stop_id)
      .gte('reported_at', sinceIso)
      .or(`reported_by.eq.${userId ?? 'null'},device_hash.eq.${body.device_hash ?? 'null'}`);

    if (recErr) {
      return new Response(JSON.stringify({ error: recErr.message }), { status: 500, headers: { "Content-Type": "application/json" } });
    }
    if (recent && recent.length > 0) {
      const COOLDOWN_MIN = Number(Deno.env.get("PARKING_COOLDOWN_MIN") ?? "10");
      return new Response(JSON.stringify({ error: "rate_limited", retry_after_seconds: COOLDOWN_MIN * 60 }), { status: 429, headers: { "Content-Type": "application/json" } });
    }

    const row = {
      stop_id: body.stop_id,
      kind: body.kind,
      value: typeof body.value === 'number' ? body.value : null,
      reported_by: userId,
      device_hash: body.device_hash ?? null,
      source: 'crowd',
    } as any;

    const { error: insErr } = await supabase.from('parking_reports').insert(row);
    if (insErr) {
      return new Response(JSON.stringify({ error: insErr.message }), { status: 500, headers: { "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ ok: true }), { status: 201, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
