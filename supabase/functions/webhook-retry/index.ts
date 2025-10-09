// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SERVICE_ROLE") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

serve(async () => {
  if (Deno.env.get("WEBHOOK_RETRY_ENABLED") !== "1") return new Response("disabled");

  const { data: jobs, error } = await supa
    .from("webhook_retry")
    .select("*")
    .eq("status", "queued")
    .lte("next_run_at", new Date().toISOString())
    .order("next_run_at", { ascending: true })
    .limit(10);

  if (error) return new Response(`error: ${error.message}`, { status: 500 });

  for (const j of jobs ?? []) {
    await supa.from("webhook_retry").update({ status: "running" }).eq("id", (j as any).id);
    try {
      // TODO: dispatch provider-specific processing for (j as any).provider and (j as any).event_id
      await supa.from("webhook_retry").update({ status: "ok" }).eq("id", (j as any).id);
    } catch (e) {
      const attempt = ((j as any).attempt ?? 0) + 1;
      const backoffSec = Math.min(3600, Math.pow(2, attempt) * 15);
      await supa
        .from("webhook_retry")
        .update({
          attempt,
          status: attempt >= ((j as any).max_attempts ?? 6) ? "err" : "queued",
          next_run_at: new Date(Date.now() + backoffSec * 1000).toISOString(),
          last_error: String(e),
        })
        .eq("id", (j as any).id);
    }
  }

  return new Response("ok");
});