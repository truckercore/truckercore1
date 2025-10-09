// TypeScript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { expiryFor } from "../_lib/classifier.ts";

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const feedUrl = Deno.env.get("NOAA_FEED_URL")!;
  const res = await fetch(feedUrl);
  if (!res.ok) return new Response("NOAA fetch fail", { status: 500 });
  const data = await res.json();

  const rows = (data.features ?? []).slice(0, 50).map((f: any) => ({
    user_id: null,
    event_type: "WEATHER",
    raw_label: f.properties?.headline ?? "Weather alert",
    confidence: 0.9,
    spam_score: 0,
    details: f.properties ?? {},
    geom: `SRID=4326;POINT(${f.geometry.coordinates[0]} ${f.geometry.coordinates[1]})`,
    radius_m: 2000,
    source: "noaa",
    expires_at: expiryFor("WEATHER")
  }));
  if (rows.length) await supabase.from("crowd_reports").insert(rows);
  return new Response(JSON.stringify({ inserted: rows.length }), { headers: { "Content-Type": "application/json" } });
});
