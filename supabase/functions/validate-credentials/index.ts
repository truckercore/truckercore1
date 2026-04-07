// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type Body = {
  org_id: string;
  role: "owner_operator" | "fleet_manager" | "broker" | "truck_stop_admin";
  credentials: {
    dot?: string;
    mc?: string;
    scac?: string;
    ein?: string; // full; we will hash + last4
    insurance_coi_url?: string;
    documents?: Record<string, unknown>;
    cdl_last4?: string;
    fleet_size?: number;
    legal_entity?: string;
    store_ids?: string[];
  };
};

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!serviceKey || !supabaseUrl) return new Response("Config error", { status: 500 });

  const supabase = createClient(supabaseUrl, serviceKey);
  const body = (await req.json()) as Body;

  // Basic validation rules per role
  const errs: string[] = [];
  const { role, credentials } = body;
  const dot = credentials.dot?.trim();
  const mc = credentials.mc?.trim();
  const scac = credentials.scac?.trim();
  const ein = credentials.ein?.replace(/[^0-9]/g, "");
  const hasCOI = !!credentials.insurance_coi_url;

  const require = (cond: boolean, msg: string) => { if (!cond) errs.push(msg); };

  if (role === "owner_operator") {
    require(!!dot, "DOT is required");
    if (!hasCOI) errs.push("Insurance COI required");
  } else if (role === "fleet_manager") {
    require(!!dot, "DOT is required");
    if (mc && !/^\d{6,7}$/.test(mc)) errs.push("MC format invalid");
    if (scac && !/^[A-Z]{2,4}$/.test(scac)) errs.push("SCAC format invalid");
    if (!hasCOI) errs.push("Carrier COI required");
  } else if (role === "broker") {
    require(!!mc, "MC (broker) is required");
  } else if (role === "truck_stop_admin") {
    require(!!ein, "EIN required");
    if (!credentials.store_ids?.length) errs.push("Store IDs required");
  }

  const checks: Record<string, unknown> = {
    dot_format_ok: dot ? /^\d{1,8}$/.test(dot) : false,
    mc_format_ok: mc ? /^\d{6,7}$/.test(mc) : false,
    scac_format_ok: scac ? /^[A-Z]{2,4}$/.test(scac) : false,
    coi_present: hasCOI,
  };

  const status = errs.length ? "pending" : "verified";

  // Prepare masked EIN
  let ein_last4: string | null = null;
  let ein_hash: string | null = null;
  if (ein && /^\d{9}$/.test(ein)) {
    ein_last4 = ein.slice(-4);
    const { data: hashData } = await supabase.rpc("hash_ein", { p_ein: ein });
    if (typeof hashData === 'string') ein_hash = hashData as string;
  }

  // Upsert org_credentials
  const { error: upErr } = await supabase
    .from("org_credentials")
    .upsert(
      {
        org_id: body.org_id,
        dot, mc, scac,
        ein_last4,
        ein_hash,
        insurance_coi_url: credentials.insurance_coi_url ?? null,
        documents: credentials.documents ?? {},
        updated_at: new Date().toISOString(),
      },
      { onConflict: "org_id" }
    );
  if (upErr) return new Response(upErr.message, { status: 400 });

  // Create verification record
  const { error: vErr } = await supabase
    .from("verifications")
    .insert({
      org_id: body.org_id,
      source: "api",
      status,
      notes: errs.join("; "),
      checks,
    });
  if (vErr) return new Response(vErr.message, { status: 400 });

  return new Response(JSON.stringify({ status, errors: errs, checks }), { status: 200, headers: { "Content-Type": "application/json" } });
});
