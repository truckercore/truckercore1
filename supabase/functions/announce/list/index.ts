import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const audience = url.searchParams.get("audience") ?? "driver";
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const since = new Date(Date.now() - 30 * 864e5).toISOString();
  const { data, error } = await sb
    .from("feature_announcements")
    .select("*")
    .eq("audience", audience)
    .gte("created_at", since)
    .order("created_at", { ascending: false })
    .limit(5);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "content-type": "application/json" } });
  return new Response(JSON.stringify({ items: data || [] }), { headers: { "content-type": "application/json" } });
});
