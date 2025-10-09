import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    // Service role lets us probe infra safely without exposing to users
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const checks: Record<string, unknown> = {};
  let ok = true;
  const fail = (k: string, msg: string) => {
    ok = false;
    (checks as any)[k] = { ok: false, msg };
  };

  // 1) DB connectivity
  try {
    // Prefer a cheap RPC like "now" if present
    const { error } = await supabase.rpc("now");
    if (error) {
      // Fallback trivial select if rpc missing
      const fb = await supabase.from("orgs").select("id").limit(1);
      if (fb.error) fail("db", `${error.message}; fallback: ${fb.error.message}`);
      else (checks as any).db = { ok: true };
    } else {
      (checks as any).db = { ok: true };
    }
  } catch (e: any) {
    fail("db", e?.message ?? "unknown");
  }

  // 2) Ops views readable
  try {
    const { data, error } = await supabase
      .from("ops_alerts_pending")
      .select("*")
      .limit(1);
    if (error) fail("ops_views", error.message);
    else (checks as any).ops_views = { ok: true, sample: data?.length ?? 0 };
  } catch (e: any) {
    fail("ops_views", e?.message ?? "unknown");
  }

  // 3) Storage signed upload (docs bucket exists & policy intact)
  try {
    const testPath = `health/healthz-${crypto.randomUUID()}.txt`;
    const { error } = await supabase.storage
      .from("docs")
      .createSignedUploadUrl(testPath);
    if (error) fail("storage", error.message);
    else (checks as any).storage = { ok: true };
  } catch (e: any) {
    fail("storage", e?.message ?? "unknown");
  }

  // 4) Stripe secret present (don’t call Stripe here)
  try {
    const present = !!Deno.env.get("STRIPE_SECRET_KEY");
    if (!present) fail("stripe_env", "STRIPE_SECRET_KEY missing");
    else (checks as any).stripe_env = { ok: true };
  } catch (e: any) {
    fail("stripe_env", e?.message ?? "unknown");
  }

  const status = ok ? 200 : 503;
  return new Response(JSON.stringify({ ok, checks }, null, 2), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" }
  });
});
