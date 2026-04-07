// deno-fns/saml_toggle.ts
// Endpoint: /api/saml/config/enable (POST)
// Body: { org_id: string, enabled: boolean }
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  try {
    const { org_id, enabled } = await req.json();
    if (!org_id || typeof enabled !== "boolean") return new Response("Bad Request", { status: 400 });
    const { error } = await db.from("saml_configs").update({ enabled, updated_at: new Date().toISOString() }).eq("org_id", org_id);
    if (error) return new Response(error.message, { status: 500 });
    return new Response("ok");
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
