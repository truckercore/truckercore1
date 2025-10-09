import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

serve(async (req) => {
  try {
    const { user_id } = await req.json();
    if (!user_id) return new Response("user_id required", { status: 400 });

    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SERVICE_ROLE_KEY");
    if (!url || !key) return new Response("Server misconfigured", { status: 500 });

    const admin = createClient(url, key, { auth: { persistSession: false } });

    const { data: cred, error: cerr } = await admin
      .from("credentials")
      .select("dot, mc, role_hint")
      .eq("user_id", user_id)
      .maybeSingle();
    if (cerr) return new Response(cerr.message, { status: 500 });
    if (!cred) return new Response("missing", { status: 404 });

    const ok = /^\d{6,8}$/.test(String(cred.dot || ""));
    if (!ok) return new Response("failed", { status: 422 });

    const { error: uerr } = await admin.auth.admin.updateUserById(user_id, {
      user_metadata: {
        app_role: cred.role_hint || "driver",
        legal_verified: true,
        dot_verified: true,
      },
    });
    if (uerr) return new Response(uerr.message, { status: 500 });

    await admin.from("driver_profiles").upsert(
      { user_id, premium: false },
      { onConflict: "user_id" } as any
    );

    return new Response("ok", { status: 200 });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 500 });
  }
});
