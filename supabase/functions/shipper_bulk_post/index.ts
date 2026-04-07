import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Row = {
  origin?: string;
  destination?: string;
  pickup_at?: string; // ISO
  dropoff_at?: string; // ISO
  equipment_type?: string | null;
  linehaul_cents?: number | null;
  accessorial_cents?: number | null;
  fuel_surcharge_cents?: number | null;
  estimated_miles?: number | null;
};

type CsvBody = { csv: string } | { rows: Row[] };

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function parseCsv(text: string): Row[] {
  // Very small CSV parser (comma, header in first line)
  const lines = text.split(/\r?\n/).filter(l => l.trim().length);
  if (!lines.length) return [];
  const headers = lines[0].split(',').map(h => h.trim());
  const rows: Row[] = [];
  for (const line of lines.slice(1)) {
    const cols = line.split(',');
    const m: any = {};
    headers.forEach((h, i) => m[h] = (cols[i] ?? '').trim());
    rows.push({
      origin: m.origin || m.Origin || m.origin_zip || m.origin_city,
      destination: m.destination || m.Destination || m.dest_zip || m.dest_city,
      pickup_at: m.pickup_at || m.pickup || m.pickup_date,
      dropoff_at: m.dropoff_at || m.dropoff || m.delivery_date,
      equipment_type: m.equipment_type || m.equipment || null,
      linehaul_cents: m.linehaul_cents ? Number(m.linehaul_cents) : (m.linehaul_usd ? Math.round(Number(m.linehaul_usd) * 100) : null),
      accessorial_cents: m.accessorial_cents ? Number(m.accessorial_cents) : null,
      fuel_surcharge_cents: m.fuel_surcharge_cents ? Number(m.fuel_surcharge_cents) : null,
      estimated_miles: m.estimated_miles ? Number(m.estimated_miles) : null,
    });
  }
  return rows;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Use POST", { status: 405 });
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
    const body = (await req.json()) as CsvBody;
    const rows: Row[] = ("csv" in body) ? parseCsv((body as any).csv) : (body as any).rows;
    if (!rows || !Array.isArray(rows) || rows.length === 0) {
      return new Response(JSON.stringify({ error: "no rows" }), { status: 400, headers: { "content-type": "application/json" } });
    }

    const inserts: any[] = [];
    for (const r of rows) {
      if (!r.origin || !r.destination) continue;
      const pickup = r.pickup_at ? new Date(r.pickup_at).toISOString() : new Date(Date.now() + 24*3600*1000).toISOString();
      const dropoff = r.dropoff_at ? new Date(r.dropoff_at).toISOString() : new Date(Date.now() + 48*3600*1000).toISOString();

      // Market rate lookup (latest)
      let marketAvgCents: number | null = null;
      let forecastCents: number | null = null;
      try {
        const laneKey = `${(r.origin||'').trim()}->${(r.destination||'').trim()}`;
        const { data: mr } = await supabase
          .from('market_rates')
          .select('avg_rate_cents, forecast_rate_cents')
          .eq('lane_key', laneKey)
          .order('collected_at', { ascending: false })
          .limit(1);
        if (mr && mr.length) {
          const m = mr[0] as any;
          marketAvgCents = (m.avg_rate_cents as number) ?? null;
          forecastCents = (m.forecast_rate_cents as number) ?? null;
        }
      } catch (_) {}

      inserts.push({
        origin: r.origin,
        destination: r.destination,
        pickup_at: pickup,
        dropoff_at: dropoff,
        status: 'posted',
        vehicle_type: r.equipment_type ?? null,
        linehaul_cents: r.linehaul_cents ?? null,
        accessorial_cents: r.accessorial_cents ?? null,
        fuel_surcharge_cents: r.fuel_surcharge_cents ?? null,
        estimated_miles: r.estimated_miles ?? null,
        market_avg_cents: marketAvgCents,
        forecast_rate_cents: forecastCents,
      });
    }

    if (!inserts.length) {
      return new Response(JSON.stringify({ inserted: 0 }), { headers: { "content-type": "application/json" } });
    }

    const { data, error } = await supabase.from('loads').insert(inserts).select('id, origin, destination, forecast_rate_cents');
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "content-type": "application/json" } });

    return new Response(JSON.stringify({ inserted: data?.length || 0, loads: data }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});