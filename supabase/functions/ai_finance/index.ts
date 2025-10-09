// supabase/functions/ai_finance/index.ts
// Purpose: Analyze load_financials, fuel_transactions, detention_events, and HOS
// and insert recommendations into ai_financial_recommendations.
// Minimal stub implementation that demonstrates expected input/output.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

interface RecInput {
  user_id: string;
  load_id?: string;
}

serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'POST required' }), { status: 405 });
    }
    const body = (await req.json()) as RecInput;
    const userId = body.user_id;
    if (!userId) {
      return new Response(JSON.stringify({ error: 'user_id required' }), { status: 400 });
    }

    // In a real function, query Postgres for financials and events, compute savings.
    // For MVP, return 3 example recommendations and insert into table via REST.
    const now = new Date().toISOString();
    const examples = [
      {
        kind: 'fuel',
        text: 'Refuel in Harrisburg, PA instead of Newark, NJ → save $55 on this trip.',
        projected_savings_cents: 5500,
      },
      {
        kind: 'route',
        text: 'Deadhead 40 miles less by swapping sequence → +$200 margin.',
        projected_savings_cents: 20000,
      },
      {
        kind: 'detention',
        text: 'Average detention at Dallas DC: 120m. Factor into rate negotiations.',
        projected_savings_cents: 9000,
      },
    ];

    const url = Deno.env.get('SUPABASE_URL');
    const key = Deno.env.get('SUPABASE_ANON') ?? Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!Deno.env.get('SUPABASE_ANON') && Deno.env.get('SUPABASE_ANON_KEY')) {
      console.warn('[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead');
    }
    if (!url || !key) {
      // Return payload for local testing
      return new Response(JSON.stringify({ inserted: 0, examples }), { status: 200 });
    }

    const inserted: unknown[] = [];
    for (const e of examples) {
      const res = await fetch(`${url}/rest/v1/ai_financial_recommendations`, {
        method: 'POST',
        headers: {
          'apikey': key,
          'Authorization': `Bearer ${key}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify({
          user_id: userId,
          load_id: body.load_id ?? null,
          kind: e.kind,
          text: e.text,
          projected_savings_cents: e.projected_savings_cents,
          created_at: now,
        }),
      });
      const j = await res.json();
      inserted.push(j);
    }

    return new Response(JSON.stringify({ inserted: inserted.length }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
