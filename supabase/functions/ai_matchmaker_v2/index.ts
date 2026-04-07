import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

/**
 * Input: { load_id: string }
 * Output: [{ driver_id, score, rationale }]
 */
Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const { load_id } = body || {};
    if (!load_id) {
      return new Response(JSON.stringify({ error: 'load_id required' }), { status: 400 });
    }

    // 1. Get load info
    const { data: load, error: lErr } = await sb
      .from('loads')
      .select('id, origin, destination, pickup_at, dropoff_at')
      .eq('id', load_id)
      .maybeSingle();
    if (lErr || !load) {
      return new Response(JSON.stringify({ error: lErr?.message || 'load not found' }), { status: 404 });
    }

    // 2. Get candidate drivers
    const { data: drivers, error: dErr } = await sb
      .from('drivers')
      .select('id, home_base, status');
    if (dErr) {
      return new Response(JSON.stringify({ error: dErr.message }), { status: 500 });
    }

    // 3. Simple scoring (placeholder AI logic)
    const results = (drivers ?? []).map((drv: any) => {
      // Example: higher score if driver is "available"
      const score = drv.status === 'available' ? 90 : 50;
      const rationale = drv.status === 'available'
        ? 'Driver is available and near route'
        : 'Driver not available';
      return { load_id, driver_id: drv.id, score, rationale };
    });

    // 4. Insert into ai_match_scores_v2
    if (results.length > 0) {
      const { error: iErr } = await sb
        .from('ai_match_scores_v2')
        .insert(results);
      if (iErr) {
        return new Response(JSON.stringify({ error: iErr.message }), { status: 500 });
      }
    }

    return new Response(JSON.stringify(results), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e?.message || 'unknown error' }), { status: 500 });
  }
});
