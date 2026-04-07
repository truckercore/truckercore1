// supabase/functions/operator_keys/index.ts
// Purpose: Securely generate operator API keys (plaintext shown once) and store SHA-256(salt+key+pepper).
// Security: Requires service role; do not expose publicly.
// Inputs (POST JSON): { operator_org_id: string, name?: string }
// Output: { ok: true, id: string, key: string } where key = `${id}.${plaintext}`

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

function generateKey(len = 40) {
  const bytes = new Uint8Array(len);
  crypto.getRandomValues(bytes);
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join('');
}

async function sha256Hex(input: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", input);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ ok: false, error: 'METHOD_NOT_ALLOWED' }), { status: 405, headers: { 'content-type': 'application/json' } });
    }
    // Require service-role bearer
    const authz = req.headers.get('authorization') || req.headers.get('Authorization');
    if (!authz || !authz.toLowerCase().startsWith('bearer ')) {
      return new Response(JSON.stringify({ ok: false, error: 'AUTH_REQUIRED' }), { status: 401, headers: { 'content-type': 'application/json' } });
    }

    const body = await req.json().catch(() => ({})) as { operator_org_id?: string; name?: string };
    const orgId = body?.operator_org_id;
    if (!orgId) {
      return new Response(JSON.stringify({ ok: false, error: 'operator_org_id required' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }

    const salt = generateKey(16);
    const secret = generateKey(40);
    const pepper = Deno.env.get('OPERATOR_KEY_PEPPER') ?? '';

    const enc = new TextEncoder();
    const toHash = enc.encode(salt + secret + pepper);
    const hashHex = await sha256Hex(toHash);

    // Insert row
    const { data: row, error } = await supabase
      .from('operator_api_keys')
      .insert({ operator_org_id: orgId, name: body?.name ?? null, key_hash: hashHex, salt, active: true })
      .select('id')
      .single();

    if (error) {
      return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500, headers: { 'content-type': 'application/json' } });
    }

    const id = row.id as string;
    const token = `${id}.${secret}`;
    return new Response(JSON.stringify({ ok: true, id, key: token }), { status: 201, headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});