import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const json = (b: unknown, s=200) => new Response(JSON.stringify(b), { status: s, headers: { 'content-type':'application/json', 'access-control-allow-origin':'*' }});

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);
  const adminKey = Deno.env.get('ADMIN_PROMOTE_KEY');
  if (!adminKey || req.headers.get('x-admin-key') !== adminKey) return json({ error: 'unauthorized' }, 401);

  const svc = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false }});
  try {
    const b = await req.json();
    const { model_key='eta', strategy='single', active_version, control_version, candidate_version, canary_pct, version_a, version_b, split_pct } = b || {};

    // Fetch model id
    const { data: model, error: mErr } = await svc.from('ai_models').select('id').eq('key', model_key).maybeSingle();
    if (mErr || !model) return json({ error: mErr?.message || 'model_not_found' }, 400);

    // Helper to resolve version text to id if a string was passed
    async function resolve(ver: any): Promise<string|undefined> {
      if (!ver) return undefined;
      if (typeof ver === 'string' && ver.match(/^\w{8}-/)) return ver; // uuid
      const { data } = await svc.from('ai_model_versions').select('id').eq('model_id', model.id).eq('version', String(ver)).maybeSingle();
      return data?.id;
    }

    const payload: any = { strategy };
    const aid = await resolve(active_version); if (aid) payload.active_version_id = aid;
    const cid = await resolve(control_version); if (cid) payload.control_version_id = cid;
    const kid = await resolve(candidate_version); if (kid) payload.candidate_version_id = kid;
    const va  = await resolve(version_a); if (va) payload.version_a_id = va;
    const vb  = await resolve(version_b); if (vb) payload.version_b_id = vb;
    if (typeof canary_pct === 'number') payload.canary_pct = canary_pct;
    if (typeof split_pct === 'number') payload.split_pct = split_pct;

    // Upsert rollout row for model
    const { error: upErr } = await svc.from('ai_rollouts').upsert({ model_id: model.id, ...payload }, { onConflict: 'model_id' });
    if (upErr) return json({ error: upErr.message }, 500);

    return json({ ok: true, rollout: payload });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 400);
  }
});
