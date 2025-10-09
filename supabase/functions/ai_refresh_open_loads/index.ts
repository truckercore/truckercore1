import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

Deno.serve(async () => {
  try {
    const { data: loads, error } = await sb
      .from('loads')
      .select('id')
      .in('status', ['posted','in_transit'])
      .limit(200);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' } });
    if (!loads?.length) return new Response(JSON.stringify({ refreshed: 0 }), { status: 200, headers: { 'content-type': 'application/json' } });

    let ok = 0;
    for (const row of loads) {
      await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/ai_matchmaker`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ load_id: row.id })
      }).then(r => { if (r.ok) ok++; });
      await new Promise(res => setTimeout(res, 120));
    }

    return new Response(JSON.stringify({ refreshed: ok }), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});