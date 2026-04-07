// deno-fns/roi_export.ts
// Export 30d ROI summary for an org in JSON or CSV
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // align with env.example
const db = createClient(url, service, { auth: { persistSession: false }});

Deno.serve(async (req) => {
  const u = new URL(req.url);
  const org_id = u.searchParams.get('org_id') ?? '';
  const format = (u.searchParams.get('format') ?? 'json').toLowerCase();
  if (!org_id) return new Response(JSON.stringify({ error: 'org_id required' }), { status: 400, headers: {"content-type":"application/json"} });

  const { data, error } = await db
    .from('v_ai_roi_exec_30d')
    .select('*')
    .eq('org_id', org_id)
    .single();
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: {"content-type":"application/json"} });

  if (format === 'csv') {
    const headers = ['org_id','fuel_saved_30d_usd','promo_uplift_30d_usd','hos_avoid_30d_usd','events_30d'];
    const row = headers.map(h => (data as any)[h]);
    const csv = headers.join(',') + '\n' + row.join(',') + '\n';
    return new Response(csv, { headers: { "content-type": "text/csv" } });
  }
  return new Response(JSON.stringify(data), { headers: { "content-type": "application/json" } });
});
