import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const NOTICE_WEBHOOK = Deno.env.get("BILLING_NOTICE_WEBHOOK")!;
const OPEN_TO_DUE_DAYS = Number(Deno.env.get("OPEN_TO_DUE_DAYS") || "7");

serve(async () => {
  const s = createClient(url, key, { auth: { persistSession: false }});

  await s.rpc("mark_open_invoices_due", { p_days: OPEN_TO_DUE_DAYS });

  const since = new Date(Date.now()-24*3600*1000).toISOString();
  const { data, error } = await s
    .from("invoices")
    .select("id, org_id, number, total_cents")
    .eq("status","due")
    .gte("created_at", since);

  if (error) return new Response(error.message, { status: 500 });

  if (data && data.length && NOTICE_WEBHOOK) {
    await fetch(NOTICE_WEBHOOK, {
      method:"POST", headers:{ "Content-Type":"application/json" },
      body: JSON.stringify({ text: `New DUE invoices: ${data.map(d=>d.number).join(", ")}` })
    });
  }
  return new Response(JSON.stringify({ ok:true, count: data?.length ?? 0 }), {
    headers: { "Content-Type":"application/json" }
  });
});
