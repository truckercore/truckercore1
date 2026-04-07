const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "authorization, content-type",
  "cache-control": "public, max-age=30, stale-while-revalidate=120",
};
const ok = (b: unknown) => new Response(JSON.stringify(b), { status: 200, headers: { "content-type": "application/json", ...cors } });
const bad = (m: string, s = 400) => new Response(JSON.stringify({ error: m }), { status: s, headers: { "content-type": "application/json", ...cors } });

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("", { headers: cors });
  if (req.method !== "GET") return bad("method not allowed", 405);

  const url = new URL(req.url);
  const bbox = url.searchParams.get("bbox"); // minLng,minLat,maxLng,maxLat
  if (!bbox) return bad("missing bbox");
  const parts = bbox.split(",").map(Number);
  if (parts.length !== 4 || parts.some((v) => Number.isNaN(v))) return bad("invalid bbox");
  const [minLng, minLat, maxLng, maxLat] = parts;

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);
  const { data, error } = await sb.rpc("poi_weigh_bbox", { minlng: minLng, minlat: minLat, maxlng: maxLng, maxlat: maxLat });
  if (error) return bad(error.message, 500);
  return ok({ pois: data ?? [] });
});
