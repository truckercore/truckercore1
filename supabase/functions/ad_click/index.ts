// supabase/functions/ad_click/index.ts
// Records an ad click with optional device hash and tracking token.

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

    const body = await req.json().catch(() => ({})) as { ad_id?: string; device_hash?: string; tracking_token?: string };
    if (!body.ad_id) {
      return new Response(JSON.stringify({ error: "ad_id required" }), { status: 400, headers: { "Content-Type": "application/json" } });
    }

    const claims = parseJwt<Claims>(req.headers.get('Authorization'));
    const userId = claims?.sub ?? null;

    const { error } = await supabase.from("ad_clicks").insert({
      ad_id: body.ad_id,
      user_id: userId,
      device_hash: body.device_hash ?? null,
      tracking_token: body.tracking_token ?? null
    } as any);

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ ok: true }), { status: 201, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
