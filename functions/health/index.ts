import { adminClient, corsHeaders } from '../_shared/client.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req.headers.get('origin')) });

  try {
    const { data, error } = await adminClient.rpc('edge_health_now');
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true, now: data }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders(req.headers.get('origin')) },
      status: 200,
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders(req.headers.get('origin')) },
      status: 500,
    });
  }
});
