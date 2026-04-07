import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

/* Input: { load_id?: string, near_lat?: number, near_lon?: number, radius_mi?: number }
   Output: { suggestions: [{ id, origin, destination, distance_mi }] }
   MVP: if load_id provided, use its destination_lat/lon; else use near_lat/lon.
*/

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function haversineMi(a:{lat:number,lon:number}, b:{lat:number,lon:number}): number {
  const R=3958.8; const dLat=(b.lat-a.lat)*Math.PI/180; const dLon=(b.lon-a.lon)*Math.PI/180;
  const sa=Math.sin(dLat/2)**2 + Math.cos(a.lat*Math.PI/180)*Math.cos(b.lat*Math.PI/180)*Math.sin(dLon/2)**2;
  return 2*R*Math.atan2(Math.sqrt(sa), Math.sqrt(1-sa));
}

serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Use POST', { status: 405 });
    const { load_id, near_lat, near_lon, radius_mi } = await req.json();
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    let center: { lat: number, lon: number } | null = null;
    if (load_id) {
      const { data: load } = await supabase.from('loads').select('destination_lat, destination_lon').eq('id', load_id).maybeSingle();
      if (load && typeof (load as any).destination_lat === 'number' && typeof (load as any).destination_lon === 'number') {
        center = { lat: (load as any).destination_lat, lon: (load as any).destination_lon };
      }
    }
    if (!center && typeof near_lat === 'number' && typeof near_lon === 'number') {
      center = { lat: Number(near_lat), lon: Number(near_lon) };
    }
    if (!center) return new Response(JSON.stringify({ error: 'no center' }), { status: 400, headers: { 'content-type': 'application/json' } });

    const { data: loads, error } = await supabase.from('loads').select('id, origin, destination, origin_lat, origin_lon, status').in('status', ['posted','draft']).limit(200);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' } });

    const rad = Number(radius_mi ?? 100);
    const suggestions = (loads ?? []).map((l: any) => {
      if (typeof l.origin_lat === 'number' && typeof l.origin_lon === 'number') {
        const d = haversineMi(center!, { lat: l.origin_lat, lon: l.origin_lon });
        return { id: l.id, origin: l.origin, destination: l.destination, distance_mi: Math.round(d) };
      }
      return null;
    }).filter(Boolean as any).filter((s: any) => s.distance_mi <= rad).sort((a: any, b: any) => a.distance_mi - b.distance_mi).slice(0, 20);

    return new Response(JSON.stringify({ suggestions }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});