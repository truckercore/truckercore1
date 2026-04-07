// supabase/functions/aggregate-kpis/index.ts
// Hourly aggregator: upsert locale KPI counts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async () => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) return new Response("Supabase env not configured", { status: 500 });

    const supabase = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

    const { data: rows, error } = await supabase.from("v_kpi_locale_hour").select("*");
    if (error) return new Response(error.message, { status: 500 });

    if (rows && Array.isArray(rows)) {
      for (const r of rows as any[]) {
        const { error: upErr } = await supabase
          .from("kpi_locale_daily")
          .upsert(
            {
              day: r.day,
              locale: r.locale,
              acks_count: r.acks_count,
              org_id: null,
              corridor_id: null,
            },
            { onConflict: "day,locale,org_id,corridor_id" }
          );
        if (upErr) return new Response(upErr.message, { status: 500 });
      }
    }

    return new Response(JSON.stringify({ ok: true }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
});
