import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const FCM_KEY = Deno.env.get('FCM_SERVER_KEY')!;

Deno.serve(async (req) => {
  try {
    const body = await req.json(); // { user_ids:[], title, body, data:{} }
    const { user_ids, title, body: msg, data } = body;
    if (!Array.isArray(user_ids) || !user_ids.length) {
      return new Response(JSON.stringify({ error: 'user_ids required' }), { status: 400 });
    }
    const { data: tokens } = await sb.from('push_tokens').select('fcm_token').in('user_id', user_ids);
    if (!tokens?.length) return new Response(JSON.stringify({ sent:0 }), { status: 200 });

    const res = await fetch('https://fcm.googleapis.com/fcm/send', {
      method:'POST',
      headers:{ 'Authorization': `key=${FCM_KEY}`, 'Content-Type':'application/json' },
      body: JSON.stringify({
        registration_ids: (tokens as any[]).map(t=>t.fcm_token),
        notification: { title, body: msg },
        data: data ?? {},
      })
    });
    const j = await res.json();
    return new Response(JSON.stringify({ fcm:j }), { status: 200, headers: { 'content-type':'application/json' } });
  } catch (e:any) {
    return new Response(JSON.stringify({ error: e?.message || 'notify error' }), { status: 500, headers: { 'content-type':'application/json' } });
  }
});