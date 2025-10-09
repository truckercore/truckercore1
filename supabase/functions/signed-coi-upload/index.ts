// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

const MAX_BYTES = 20 * 1024 * 1024;
const ALLOWED = new Set(["application/pdf","image/jpeg","image/png","image/heic"]);

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_KEY =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
    Deno.env.get("SUPABASE_SERVICE_ROLE") ||
    Deno.env.get("SUPABASE_SERVICE_KEY") ||
    Deno.env.get("SERVICE_ROLE_KEY");
  if (!SUPABASE_URL || !SERVICE_KEY) return new Response("Server misconfig", { status: 500 });

  const supa = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

  const auth = req.headers.get("Authorization") || "";
  const jwt = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!jwt) return new Response("Unauthorized", { status: 401 });

  const userResp = await supa.auth.getUser(jwt);
  if (userResp.error || !userResp.data.user) return new Response("Unauthorized", { status: 401 });
  const user = userResp.data.user;
  const org_id = (user.user_metadata?.app_org_id as string) || (user.user_metadata?.org_id as string) || null;
  if (!org_id) return new Response("Missing org", { status: 400 });

  const body = await req.json().catch(() => ({}));
  const { fileName, mime, sizeBytes } = body as { fileName: string; mime: string; sizeBytes: number };

  if (!fileName || !mime || typeof sizeBytes !== "number") return new Response("Bad Request", { status: 400 });
  if (!ALLOWED.has(mime)) return new Response("Unsupported type", { status: 415 });
  if (sizeBytes <= 0 || sizeBytes > MAX_BYTES) return new Response("Too large", { status: 413 });

  const safeName = fileName.replace(/[^\w.\-]/g, "_");
  const key = `coi/${org_id}/${user.id}/${crypto.randomUUID()}_${safeName}`;

  // Create a signed upload URL valid for 60 seconds
  const { data: signed, error: signErr } = await supa.storage.from("coi").createSignedUploadUrl(key, 60);
  if (signErr || !signed) return new Response(`Failed to sign: ${signErr?.message || "unknown"}`, { status: 500 });

  // Record COI metadata row (verification pending)
  const { error: insErr } = await supa.from("coi_documents").insert({
    org_id, user_id: user.id, file_key: key, mime, size_bytes: sizeBytes, verified: false
  });
  if (insErr) return new Response(`Insert failed: ${insErr.message}`, { status: 500 });

  return new Response(JSON.stringify({ signedUrl: signed.signedUrl, path: key }), {
    headers: { "Content-Type": "application/json" },
  });
});