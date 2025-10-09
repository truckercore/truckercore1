// TypeScript (Deno)
// Edge Function: ingest_rates
// Validate via JSON Schema; quarantine bad rows; enforce freshness SLOs
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Ajv from "npm:ajv";

const schema = {
  type: 'object',
  properties: {
    lane_key: { type: 'string' },
    day: { type: 'string', format: 'date' },
    source: { type: 'string' },
    price: { type: 'number' },
    confidence: { type: 'number', minimum: 0, maximum: 1 },
    collected_at: { type: 'string', format: 'date-time' }
  },
  required: ['lane_key','day','source','price','collected_at']
} as const;

serve(async (req) => {
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!SUPABASE_URL || !SERVICE_KEY) {
      return new Response("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", { status: 500 });
    }
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    const ajv = new Ajv({ allErrors: true });
    const validate = ajv.compile(schema);
    const body = await req.json();

    const rows: any[] = Array.isArray(body) ? body : [body];
    const bad: any[] = []; const good: any[] = [];
    for (const row of rows) {
      if (!validate(row)) { bad.push({ row, errors: validate.errors }); continue; }
      good.push(row);
    }

    if (good.length) {
      const { error } = await supabase.from('market_rates').upsert(good, { onConflict: 'lane_key,day,source' });
      if (error) return new Response(error.message, { status: 500 });
    }
    if (bad.length) {
      // Best-effort quarantine if table exists
      await supabase.from('quarantine_market_rates').insert(bad.map(b => ({ payload: b.row, errors: b.errors }))); // may fail if table absent
    }

    // Freshness SLOs
    const maxDay = good.length ? Math.max(...good.map((g) => Date.parse(g.day))) : Date.now();
    const ageHours = (Date.now() - maxDay) / 36e5;
    if (ageHours > 24) {
      // Best-effort alerting if alerts table exists
      await supabase.from('alerts').insert({ topic: 'rates_freshness', severity: 'high', detail: { ageHours } } as any);
    }

    return new Response(JSON.stringify({ ok: true, inserted: good.length, quarantined: bad.length }), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (e: any) {
    return new Response(`Error: ${e?.message || 'unknown'}`, { status: 500 });
  }
});