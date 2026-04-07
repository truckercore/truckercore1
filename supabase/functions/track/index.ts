// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

serve(async (req) => {
  if (req.method !== "POST") return new Response("405", { status: 405 });

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_KEY =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
    Deno.env.get("SUPABASE_SERVICE_ROLE") ||
    Deno.env.get("SUPABASE_SERVICE_KEY") ||
    Deno.env.get("SERVICE_ROLE_KEY");
  if (!SUPABASE_URL || !SERVICE_KEY) return new Response("Server misconfig", { status: 500 });

  const supa = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
  const auth = req.headers.get("Authorization") ?? "";
  const jwt = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  const { data: u } = await supa.auth.getUser(jwt ?? "");
  const body = await req.json().catch(() => ({}));

  await supa.from("event_log").insert({
    user_id: u?.user?.id ?? null,
    org_id: (u?.user?.user_metadata?.app_org_id as string) ?? (u?.user?.user_metadata?.org_id as string) ?? null,
    name: body.event ?? "unknown",
    props: body.props ?? {},
  });
  return new Response("ok");
});