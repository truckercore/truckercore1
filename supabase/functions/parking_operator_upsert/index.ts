// supabase/functions/parking_operator_upsert/index.ts
// Operator batch upsert of parking status and append reports. Requires operator_key and service role.

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

const supabaseService = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

type Body = {
  operator_key?: string;
  batch?: Array<{
    stop_id: string;
    available_total?: number | null;
    available_estimate?: number | null;
    source?: string;
  }>;
};

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'METHOD_NOT_ALLOWED' }), { status: 405, headers: { 'Content-Type': 'application/json' } });
    }
    const body = await req.json().catch(() => ({})) as Body;
    if (!body?.operator_key || !Array.isArray(body.batch) || body.batch.length === 0) {
      return new Response(JSON.stringify({ error: "operator_key and non-empty batch[] required" }), { status: 400, headers: { "Content-Type": "application/json" } });
    }

    // Validate operator_key: expected format "<id>.<secret>"
    const token = body.operator_key.trim();
    const dot = token.indexOf('.')
    if (dot <= 0) {
      return new Response(JSON.stringify({ error: "INVALID_OPERATOR_KEY" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }
    const keyId = token.slice(0, dot);
    const secret = token.slice(dot + 1);

    const { data: keyRow, error: keyErr } = await supabaseService
      .from('operator_api_keys')
      .select('id, salt, key_hash, active')
      .eq('id', keyId)
      .maybeSingle();
    if (keyErr) {
      return new Response(JSON.stringify({ error: keyErr.message }), { status: 500, headers: { "Content-Type": "application/json" } });
    }
    if (!keyRow || keyRow.active !== true) {
      return new Response(JSON.stringify({ error: "INVALID_OPERATOR_KEY" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }

    const pepper = Deno.env.get('OPERATOR_KEY_PEPPER') ?? '';
    const enc = new TextEncoder();
    const digest = await crypto.subtle.digest('SHA-256', enc.encode(String(keyRow.salt) + secret + pepper));
    const calc = Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2,'0')).join('');
    if (calc !== keyRow.key_hash) {
      return new Response(JSON.stringify({ error: "INVALID_OPERATOR_KEY" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }

    const rows = (body.batch || []).map((b) => ({
      stop_id: b.stop_id,
      available_total: (typeof b.available_total === 'number' && b.available_total >= 0) ? b.available_total : null,
      available_estimate: (typeof b.available_estimate === 'number' && b.available_estimate >= 0) ? b.available_estimate : null,
      confidence: 0.95,
      last_reported_by: (b.source ?? 'operator'),
      last_reported_at: new Date().toISOString()
    }));

    // Upsert latest status per stop (requires a unique index/constraint on stop_id)
    const { error: upErr } = await supabaseService
      .from("parking_status")
      .upsert(rows as any, { onConflict: "stop_id" });

    if (upErr) {
      return new Response(JSON.stringify({ error: upErr.message }), { status: 500, headers: { "Content-Type": "application/json" } });
    }

    // Append a parking_reports row per update
    const reportRows = (body.batch || []).map((b) => ({
      stop_id: b.stop_id,
      reported_by: null,
      device_hash: null,
      kind: (typeof b.available_estimate === 'number') ? 'count' : 'open',
      value: (typeof b.available_estimate === 'number') ? b.available_estimate : null,
      source: b.source ?? 'operator'
    }));
    const { error: repErr } = await supabaseService.from("parking_reports").insert(reportRows as any);
    if (repErr) {
      // Don’t fail overall if reports fail; log and continue
      console.warn("parking_reports insert error:", repErr.message);
    }

    return new Response(JSON.stringify({ ok: true, updated: rows.length }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
