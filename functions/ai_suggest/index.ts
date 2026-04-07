import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
const json = (b: unknown, s=200) => new Response(JSON.stringify(b), { status: s, headers: { "content-type":"application/json", "access-control-allow-origin":"*" }});

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") || "" } } });
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);

  const body = await req.json().catch(()=> ({}));
  const { conv_id, message } = body;
  if (!conv_id || typeof message !== "string") return json({ error: "bad input" }, 400);

  await sb.from("ai_messages").insert({ conv_id, role: "user", content: message });
  // TODO: call model. For now, echo:
  const reply = `Noted. For parking near you, check POIs with bbox.`;
  await sb.from("ai_messages").insert({ conv_id, role: "assistant", content: reply });

  return json({ reply });
});
