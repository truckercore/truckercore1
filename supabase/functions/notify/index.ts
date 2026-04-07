import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE")!);

async function sendEmail(_to:string,_template:string,_payload:any){ /* TODO: integrate provider */ }
async function sendSMS(_to:string,_template:string,_payload:any){ /* TODO: integrate provider */ }

Deno.serve( async () => {
  const { data, error } = await supa.from("outbound_messages").select("*").eq("status","queued").order("created_at",{ascending:true}).limit(50);
  if (error) return new Response(JSON.stringify({ error }), { status: 500 });
  for (const m of (data ?? [])) {
    try {
      if (m.channel === "email") await sendEmail(m.to_addr, m.template, m.payload);
      else await sendSMS(m.to_addr, m.template, m.payload);
      await supa.from("outbound_messages").update({ status:"sent", sent_at: new Date().toISOString(), last_error: null }).eq("id", m.id);
    } catch (e) {
      await supa.from("outbound_messages").update({ status:"failed", last_error: String(e) }).eq("id", m.id);
    }
  }
  return new Response(JSON.stringify({ processed: data?.length ?? 0 }), { headers: { "Content-Type":"application/json" }});
});
