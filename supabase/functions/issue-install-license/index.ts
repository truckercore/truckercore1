// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

type Body = {
  org_id: string;
  role: "owner_operator" | "fleet_manager" | "broker" | "truck_stop_admin";
  device_fingerprint: string;
};

const tierCaps: Record<string, number> = {
  Basic: 2,
  Standard: 10,
  Premium: 50,
  Enterprise: 5000,
};

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const jwtSecret = Deno.env.get("INSTALL_JWT_SECRET");
  if (!serviceKey || !supabaseUrl || !jwtSecret) return new Response("Config error", { status: 500 });

  const supabase = createClient(supabaseUrl, serviceKey);
  const body = (await req.json()) as Body;

  // Load org tier
  const { data: org, error: orgErr } = await supabase
    .from("organizations")
    .select("id, tier")
    .eq("id", body.org_id)
    .single();
  if (orgErr || !org) return new Response("Org not found", { status: 404 });

  const cap = tierCaps[(org as any).tier] ?? 1;

  // Count active installs
  const { count: activeCount } = await supabase
    .from("device_installs")
    .select("install_id", { count: "exact", head: true })
    .eq("org_id", body.org_id)
    .is("revoked_at", null);
  if ((activeCount ?? 0) >= cap) return new Response("Install limit reached for tier", { status: 403 });

  // Insert install row
  const { data: row, error: upErr } = await supabase
    .from("device_installs")
    .insert({
      org_id: body.org_id,
      role: body.role,
      tier: (org as any).tier,
      device_fingerprint: body.device_fingerprint,
    })
    .select("install_id")
    .single();
  if (upErr) return new Response(upErr.message, { status: 400 });

  // Issue signed license JWT (24h)
  const header = { alg: "HS256", typ: "JWT" } as const;
  const payload = {
    iss: "trucker-core",
    sub: (row as any).install_id,
    org_id: body.org_id,
    role: body.role,
    tier: (org as any).tier,
    exp: getNumericDate(60 * 60 * 24),
  } as Record<string, unknown>;
  const token = await create(header, payload, jwtSecret);

  return new Response(JSON.stringify({ token, install_id: (row as any).install_id }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
