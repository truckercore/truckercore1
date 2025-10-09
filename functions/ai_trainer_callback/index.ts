import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const json = (b: unknown, s=200) => new Response(JSON.stringify(b), { status: s, headers: { 'content-type':'application/json', 'access-control-allow-origin':'*' }});

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);
  const secret = Deno.env.get('TRAINER_WEBHOOK_SECRET');
  if (!secret || req.headers.get('x-trainer-secret') !== secret) return json({ error: 'unauthorized' }, 401);

  const svc = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false }});
  try {
    const b = await req.json();
    const { model_key='eta', job_id, status, version, artifact_url, metrics={} } = b || {};
    if (!job_id || !version || !artifact_url) return json({ error: 'bad input' }, 400);

    // Ensure model exists
    let { data: model, error: mErr } = await svc.from('ai_models').select('id').eq('key', model_key).maybeSingle();
    if (mErr) return json({ error: mErr.message }, 500);
    if (!model) {
      const ins = await svc.from('ai_models').insert({ key: model_key }).select('id').single();
      if (ins.error) return json({ error: ins.error.message }, 500);
      model = { id: ins.data.id } as any;
    }

    // Upsert model version
    const { data: verRow, error: vErr } = await svc.from('ai_model_versions')
      .upsert({ model_id: (model as any).id, version, artifact_url, status: 'shadow', metrics }, { onConflict: 'model_id,version' })
      .select('id').single();
    if (vErr) return json({ error: vErr.message }, 500);

    // Update job status/result
    const now = new Date().toISOString();
    const { error: jErr } = await svc.from('ai_training_jobs').update({ status: status ?? 'succeeded', result: { version, artifact_url, metrics }, finished_at: now }).eq('id', job_id);
    if (jErr) return json({ error: jErr.message }, 500);

    return json({ ok: true, model_version_id: verRow.id });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 400);
  }
});
