// supabase/functions/chaos-inject/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (Deno.env.get("ENV") !== "staging")
    return new Response("forbidden", { status: 403 });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const n = Number(new URL(req.url).searchParams.get("n") ?? "10");
  const now = new Date().toISOString();

  const rows = Array.from({ length: n }).map(() => ({
    fn: "instant-pay",
    actor: null,
    payload_sha256: crypto.randomUUID().replace(/-/g, ""),
    success: false,
    error: "Chaos test",
    duration_ms: 10 + Math.floor(Math.random() * 50),
    created_at: now,
  }));

  const { error } = await supabase.from("function_audit_log").insert(rows);
  if (error) return new Response(error.message, { status: 500 });

  return new Response(JSON.stringify({ inserted: n }), {
    headers: { "Content-Type": "application/json" },
  });
});
