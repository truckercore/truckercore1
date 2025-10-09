// deno-fns/token_introspect.ts
// Endpoint: /api/token/introspect (POST)
// Support-only guard with basic rate limiting; calls Postgres RPC fn_token_introspect
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

function parseJwt(token: string | null): any {
  try {
    if (!token) return {};
    const parts = token.split(".");
    if (parts.length < 2) return {};
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = atob(b64);
    return JSON.parse(json);
  } catch {
    return {};
  }
}

function isSupport(jwt: any) {
  const roles = Array.isArray(jwt?.app_roles) ? (jwt.app_roles as string[]) : [];
  const role = String(jwt?.role || "");
  return roles.includes("support") || roles.includes("admin") || role === "admin";
}

// In-memory simple limiter: per IP, 30 req / 5 min; per org (if present), 60 / 5 min
const ipBuckets = new Map<string, { ts: number; n: number }>();
const orgBuckets = new Map<string, { ts: number; n: number }>();
const WINDOW_MS = 5 * 60 * 1000;

function rateLimit(ip: string, org?: string) {
  const now = Date.now();
  const bi = ipBuckets.get(ip) ?? { ts: now, n: 0 };
  if (now - bi.ts > WINDOW_MS) { bi.ts = now; bi.n = 0; }
  bi.n += 1; ipBuckets.set(ip, bi);
  if (bi.n > 30) throw new Error("rate_limited");
  if (org) {
    const bo = orgBuckets.get(org) ?? { ts: now, n: 0 };
    if (now - bo.ts > WINDOW_MS) { bo.ts = now; bo.n = 0; }
    bo.n += 1; orgBuckets.set(org, bo);
    if (bo.n > 60) throw new Error("rate_limited");
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });

    const authz = req.headers.get('authorization');
    const bearer = authz?.startsWith('Bearer ') ? authz.slice(7) : null;
    const jwt = parseJwt(bearer);
    if (!isSupport(jwt)) return new Response('forbidden', { status: 403 });

    const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || req.headers.get('x-real-ip') || "unknown";
    const orgId = String(jwt?.app_org_id || jwt?.org_id || "");
    try { rateLimit(ip, orgId || undefined); } catch { return new Response('rate_limited', { status: 429 }); }

    const body = await req.json().catch(() => ({}));
    const token = String(body?.token || '');
    if (!token) return new Response('missing token', { status: 400 });

    const { data, error } = await db.rpc('fn_token_introspect', { p_token: token }).single();
    if (error) return new Response(error.message, { status: 500 });
    return new Response(JSON.stringify(data ?? {}), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
