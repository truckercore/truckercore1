// supabase/functions/admin_diagnostics/index.ts
// Edge Function: Returns admin diagnostics sections keyed by section name.
// Notes:
// - The underlying view should coalesce(jsonb_agg(...), '[]') so empty sections render as arrays.
// - Optionally scope to recent-only data by adding time windows in the view itself.
// - This function uses the service role to read the admin_diagnostics view.
//   Keep invocation limited to trusted callers (e.g., back-office) or fronted by your own gateway.

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

Deno.serve(async () => {
  try {
    const supa = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
    const { data, error } = await supa.from("admin_diagnostics").select("*");
    if (error) throw error;
    const rows = (data ?? []) as any[];
    const sections: Record<string, unknown> = Object.fromEntries(
      rows.map((r: any) => [r.section, r.payload])
    );
    return new Response(JSON.stringify({ ok: true, sections }), {
      headers: { "content-type": "application/json" },
      status: 200,
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      headers: { "content-type": "application/json" },
      status: 500,
    });
  }
});
