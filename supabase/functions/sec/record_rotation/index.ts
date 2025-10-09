import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  const { key_name, rotated_by, sha256_pub, evidence_url } = await req.json();
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  await sb.from("secret_rotations").insert({ key_name, rotated_by, sha256_pub, evidence_url });
  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" }
  });
});
