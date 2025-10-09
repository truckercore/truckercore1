// functions/api/gateway/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { createHash } from "https://deno.land/std@0.224.0/hash/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function bad(status: number, msg: string) {
  return new Response(JSON.stringify({ error: msg }), { status, headers: { "content-type": "application/json" } });
}

function sha256hex(s: string) {
  const h = createHash("sha256"); h.update(s); return h.toString();
}

Deno.serve(async (req) => {
  const key = req.headers.get("x-api-key");
  if (!key) return bad(401, "missing_api_key");

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});
  const hash = sha256hex(key);
  const { data: rows, error } = await supabase.from("api_keys").select("id,org_id,scope").eq("hashed_key", hash).limit(1);
  if (error || !rows?.length) return bad(401, "invalid_api_key");
  const ctx = rows[0] as { id: string; org_id: string; scope: string[] };

  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method.toUpperCase();

  const routeScopes: Array<{ test: RegExp; scope: string }> = [
    { test: /^\/api\/marketplace\/loads$/, scope: method === "GET" ? "loads.read" : "loads.write" },
    { test: /^\/api\/marketplace\/bids$/,  scope: "bids.write" },
    { test: /^\/api\/marketplace\/match$/, scope: "loads.write" }
  ];
  const matched = routeScopes.find(r => r.test.test(path));
  if (!matched) return bad(404, "route_not_found");
  if (!ctx.scope.includes(matched.scope)) return bad(403, "insufficient_scope");

  // Proxy to function route (strip /api)
  const proxied = new URL(req.url);
  proxied.pathname = path.replace(/^\/api/, "/functions/v1");

  const headers = new Headers(req.headers);
  headers.set("x-org-id", ctx.org_id);           // propagate org
  headers.set("x-api-key-id", ctx.id);           // for auditing

  const resp = await fetch(proxied.toString(), { method, headers, body: req.body });
  return new Response(await resp.arrayBuffer(), { status: resp.status, headers: resp.headers });
});
