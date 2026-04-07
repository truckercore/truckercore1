import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data, error } = await supabase.from("weekly_slo_report").select("*");
  if (error) return new Response(error.message, { status: 500 });

  const header = ["fn","calls_7d","availability_7d","p95_ms_7d","p50_ms_7d","window_start","window_end"];
  const csv = [header, ...(data ?? []).map((d: any) => [
    d.fn, d.calls_7d, d.availability_7d, d.p95_ms_7d, d.p50_ms_7d, d.window_start, d.window_end
  ])].map(r => r.join(",")).join("\n");

  await supabase.rpc("enqueue_alert", {
    p_key: "slo_weekly_report",
    p_payload: {
      subject: "Weekly SLO Report",
      csv,
      mime: "text/csv",
      filename: `slo_${new Date().toISOString().slice(0,10)}.csv`
    }
  } as any);

  return new Response(JSON.stringify({ ok: true, rows: data?.length ?? 0 }), {
    headers: { "Content-Type": "application/json" }
  });
});