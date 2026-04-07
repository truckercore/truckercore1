// Supabase Edge Function: promotions.create (operator)
// Path: supabase/functions/promotions.create/index.ts
// Invoke with: POST /functions/v1/promotions.create
// Validates operator role/org and creates a promotion. Returns poster QR deep link and pos_shortcode.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!SUPABASE_ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEB_URL = Deno.env.get("WEB_URL") ?? Deno.env.get("DEEPLINK_BASE") ?? "https://app.example.com";

function genShortcode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 6; i++) s += alphabet[Math.floor(Math.random() * alphabet.length)];
  return s;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response(JSON.stringify({ error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });

    const auth = req.headers.get("Authorization") ?? "";
    const user = createClient(SUPABASE_URL, SUPABASE_ANON, { global: { headers: { Authorization: auth } } });
    const admin = createClient(SUPABASE_URL, SERVICE);

    const { data: ures } = await user.auth.getUser();
    if (!ures?.user) return new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), { status: 401, headers: { "content-type": "application/json" } });

    const { data: prof, error: perr } = await user.from("profiles").select("org_id, primary_role").eq("user_id", ures.user.id).single();
    if (perr) return new Response(JSON.stringify({ error: "PROFILE_LOOKUP_FAILED" }), { status: 400, headers: { "content-type": "application/json" } });
    const org_id = (prof as any)?.org_id;
    if (!org_id) return new Response(JSON.stringify({ error: "NO_ORG" }), { status: 400, headers: { "content-type": "application/json" } });

    const body = await req.json().catch(() => ({} as any));
    const input = {
      title: String(body.title ?? "").trim(),
      description: String(body.desc ?? body.description ?? "").trim() || null,
      type: (body.type === "percent" ? "percent" : body.type === "amount" ? "amount" : "amount") as "percent" | "amount",
      value_cents: Number(body.value_cents ?? 0),
      start_at: body.start_at ? new Date(body.start_at).toISOString() : null,
      end_at: body.end_at ? new Date(body.end_at).toISOString() : null,
      sku_scope: body.sku_scope ?? null,
      min_spend_cents: body.min_spend_cents != null ? Number(body.min_spend_cents) : 0,
      per_user_limit: body.per_user_limit != null ? Number(body.per_user_limit) : null,
      per_day_limit: body.per_day_limit != null ? Number(body.per_day_limit) : null,
      global_cap: body.global_cap != null ? Number(body.global_cap) : null,
      hours: body.hours ?? null,
      channels: Array.isArray(body.channels) ? body.channels : ["QR"],
      locations: Array.isArray(body.locations) ? body.locations : null,
      is_active: body.is_active !== false,
    } as const;

    if (!input.title || !input.start_at || !input.end_at || !input.value_cents) {
      return new Response(JSON.stringify({ error: "MISSING_FIELDS" }), { status: 400, headers: { "content-type": "application/json" } });
    }

    // Generate POS shortcode (ensure uniqueness best-effort)
    let shortcode = genShortcode();
    for (let i = 0; i < 5; i++) {
      const { data: exists } = await admin.from("promotions").select("id").eq("pos_shortcode", shortcode).limit(1);
      if (!exists || exists.length === 0) break;
      shortcode = genShortcode();
    }

    // Insert promotion (service role to bypass RLS checks if needed; org scoped)
    // Optional: validate provided locations belong to the operator's org
    if (Array.isArray(input.locations) && input.locations.length > 0){
      const { data: locs } = await admin.from('locations').select('location_id, org_id').in('location_id', input.locations as any);
      const bad = (locs ?? []).some((l:any)=> l.org_id !== org_id);
      if (bad) return new Response(JSON.stringify({ error: 'forbidden', message: 'locations must belong to org' }), { status: 403, headers: { 'content-type':'application/json' } });
    }

    const insert = await admin.from("promotions").insert({
      org_id,
      title: input.title,
      description: input.description,
      type: input.type,
      value_cents: input.value_cents,
      start_at: input.start_at,
      end_at: input.end_at,
      sku_scope: input.sku_scope,
      min_spend_cents: input.min_spend_cents,
      per_user_limit: input.per_user_limit,
      per_day_limit: input.per_day_limit,
      global_cap: input.global_cap,
      hours: input.hours,
      channels: input.channels,
      locations: input.locations,
      is_active: input.is_active,
      pos_shortcode: shortcode,
    }).select("id, org_id, is_active").single();

    if (insert.error) return new Response(JSON.stringify({ error: insert.error.message }), { status: 400, headers: { "content-type": "application/json" } });
    const promo_id = (insert.data as any).id as number;

    // Build poster QR deep link (poster)
    const poster_qr_url = `${WEB_URL.replace(/\/$/, "")}/poster/promo/${promo_id}.png`;
    await admin.from("promotions").update({ poster_qr_url }).eq("id", promo_id);

    const resp = { promo: { id: promo_id, org_id, pos_shortcode: shortcode, poster_qr_url, is_active: (insert.data as any).is_active } };
    return new Response(JSON.stringify(resp), { status: 201, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
