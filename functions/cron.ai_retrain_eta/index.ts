import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (_req) => {
  // Enqueue a retrain job for ETA model. External trainer should poll or be triggered separately.
  const svc = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false }});
  const params = { window_minutes: Number(Deno.env.get("ETA_RETRAIN_WINDOW_MIN") ?? 1440) };
  const { error } = await svc.from("ai_training_jobs").insert({ model_key: 'eta', job_kind: 'retrain', status: 'queued', params });
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type':'application/json' }});
  return new Response(JSON.stringify({ ok: true }), { headers: { 'content-type':'application/json' }});
});
