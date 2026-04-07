// TypeScript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { classify, expiryFor } from "../_lib/classifier.ts";
import { spamScoreFor, adjustTrust } from "../_lib/trust.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

    const auth = req.headers.get("Authorization") ?? "";

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: auth } } }
    );

    const body = await req.json().catch(() => null);
    if (!body?.lon || !body?.lat || !body?.raw_label) {
      return new Response("Bad Request", { status: 400 });
    }

    // Auth user
    const { data: userRes, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userRes.user?.id) return new Response("Unauthorized", { status: 401 });
    const uid = userRes.user.id;

    // Basic spam & classification
    const label: string = String(body.raw_label).slice(0, 48);
    const { event_type, confidence } = classify(label);
    const spam_score = spamScoreFor(label, { speed: body.speed_kph, duplicatesNearby: body.dupes });

    // Profile (trust, org, etc)
    const { data: profile } = await supabase
      .from("driver_profiles")
      .select("user_id, trust_score")
      .eq("user_id", uid)
      .single();

    // Insert
    const expires_at = expiryFor(event_type);
    const { data, error } = await supabase
      .from("crowd_reports")
      .insert({
        user_id: profile?.user_id ?? uid,
        event_type,
        raw_label: label,
        confidence,
        spam_score,
        details: body.details ?? {},
        geom: `SRID=4326;POINT(${body.lon} ${body.lat})`,
        road_milepost: body.milepost ?? null,
        radius_m: body.radius_m ?? 250,
        expires_at
      })
      .select("*")
      .single();

    if (error) return new Response(error.message, { status: 400 });

    // Reputation nudges
    await adjustTrust(supabase as any, profile?.user_id ?? uid, (1 - spam_score) * 0.01, "report_submitted");

    return new Response(JSON.stringify({ ok: true, report: data }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(`Server Error: ${e}` , { status: 500 });
  }
});
