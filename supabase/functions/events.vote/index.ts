// Supabase Edge Function: events.vote
// POST /functions/v1/events.vote
// Body: { report_id, vote: -1|1 }
// Upserts a user's vote on a report and returns tallies.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");

function bad(status: number, message: string){
  return new Response(JSON.stringify({ error: message }), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return bad(405, 'method_not_allowed');
    const auth = req.headers.get('Authorization') ?? '';
    const supa = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });

    const { data: ures } = await supa.auth.getUser();
    if (!ures?.user) return bad(401, 'auth_required');

    const body = await req.json().catch(()=>({} as any));
    const report_id = String(body.report_id || '').trim();
    const voteVal = Number(body.vote);
    if (!report_id || !(voteVal === 1 || voteVal === -1)) return bad(400, 'invalid_request');

    // Ensure report exists (prevent orphans)
    const { data: rep } = await supa.from('poi_reports').select('id').eq('id', report_id).maybeSingle();
    if (!rep) return bad(404, 'report_not_found');

    // Upsert vote
    const ins = await supa.from('poi_report_votes').insert({ user_id: ures.user.id, report_id, vote: voteVal as 1 | -1 })
      .select('id')
      .single();
    if (ins.error) {
      if (ins.error.message.includes('duplicate key value')) {
        // Update existing
        const up = await supa.from('poi_report_votes').update({ vote: voteVal }).eq('report_id', report_id).eq('user_id', ures.user.id);
        if (up.error) return bad(500, up.error.message);
      } else {
        return bad(500, ins.error.message);
      }
    }

    // Tallies
    const { data: tallies } = await supa.rpc('tally_report_votes', { p_report_id: report_id }).catch(()=>({ data: null } as any));
    let up = 0, down = 0;
    if (tallies) { up = Number((tallies as any).up || 0); down = Number((tallies as any).down || 0); }
    else {
      const { data: rows } = await supa.from('poi_report_votes').select('vote').eq('report_id', report_id);
      for (const r of (rows ?? []) as any[]) { if (r.vote === 1) up++; else if (r.vote === -1) down++; }
    }

    return new Response(JSON.stringify({ ok: true, up, down }), { headers: { 'content-type': 'application/json' } });
  } catch (e) { return bad(500, String(e)); }
});
