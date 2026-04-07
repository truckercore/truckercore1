// deno run --allow-env --allow-net
import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

// Wire to your AI provider (OpenAI shown)
const LLM_API_KEY = Deno.env.get('LLM_API_KEY')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

type Role = 'driver' | 'ownerop' | 'fleet_manager' | 'broker';

type Plan = 'free'|'pro'|'premium'|'enterprise';

// Extract org/user/plan from proxy headers (replace with JWT parsing if preferred)
function getClaims(req: Request) {
  const h = req.headers;
  const org_id = h.get('x-tc-org-id') ?? '';
  const user_id = h.get('x-tc-user-id') ?? '';
  const plan_tier = (h.get('x-tc-plan') ?? 'free') as Plan;
  return { org_id, user_id, plan_tier };
}

Deno.serve(async (req) => {
  const t0 = Date.now();
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
    }

    const { org_id, user_id, plan_tier } = getClaims(req);
    if (!org_id || !user_id) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });
    }

    const body = await req.json().catch(() => ({}));
    const role = String(body.role || '') as Role;
    const prompt = String(body.prompt || '');
    const driver_user_id = body.driver_user_id ? String(body.driver_user_id) : undefined;
    const load_id = body.load_id ? String(body.load_id) : undefined;

    if (!role || !prompt) {
      return new Response(JSON.stringify({ error: 'Missing role/prompt' }), { status: 400 });
    }

    // Plan gating example (adjust as needed)
    if ((role === 'fleet_manager' || role === 'broker') && !(plan_tier === 'premium' || plan_tier === 'enterprise')) {
      return new Response(JSON.stringify({ error: 'Upgrade required' }), { status: 403 });
    }

    // 1) Pull context (org-scoped)
    const context: Record<string, unknown> = {};

    if (role === 'driver' || role === 'ownerop') {
      const { data: hos } = await sb.from('hos_logs')
        .select('start_time,end_time,status')
        .eq('org_id', org_id)
        .eq('driver_user_id', driver_user_id ?? user_id)
        .order('start_time', { ascending: false })
        .limit(10);
      const { data: inspections } = await sb.from('inspection_reports')
        .select('type,signed_at,defects,certified_safe,vehicle_id')
        .eq('org_id', org_id)
        .eq('driver_user_id', driver_user_id ?? user_id)
        .order('signed_at', { ascending: false })
        .limit(5);
      context.hos = hos ?? [];
      context.inspections = inspections ?? [];
    }

    if (role === 'ownerop') {
      const since30 = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
      const { data: expenses } = await sb.from('ownerop_expenses')
        .select('category,amount_usd,miles,incurred_on,notes')
        .eq('org_id', org_id)
        .eq('user_id', driver_user_id ?? user_id)
        .gte('incurred_on', since30)
        .order('incurred_on', { ascending: false });
      context.expenses = expenses ?? [];
    }

    if (role === 'fleet_manager' || role === 'broker') {
      const { data: loads } = await sb.from('loads')
        .select('id,origin,destination,delivery_appt_at,eta_now,status,driver_user_id')
        .eq('org_id', org_id)
        .order('delivery_appt_at', { ascending: true })
        .limit(20);
      context.loads = loads ?? [];
    }

    const { data: alerts } = await sb.from('alerts_events')
      .select('code,severity,payload,triggered_at,acknowledged')
      .eq('org_id', org_id)
      .gte('triggered_at', new Date(Date.now() - 24 * 3600 * 1000).toISOString())
      .order('triggered_at', { ascending: false });
    context.alerts = alerts ?? [];

    const { data: snaps } = await sb.from('analytics_snapshots')
      .select('date_bucket,total_loads,total_miles,revenue_usd,cost_usd,avg_ppm,on_time_pct')
      .eq('org_id', org_id)
      .gte('date_bucket', new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10))
      .order('date_bucket', { ascending: true });
    context.analytics = snaps ?? [];

    // 2) Build role-specific system prompt
    let systemPrompt = '';
    switch (role) {
      case 'driver':
        systemPrompt = 'You are a Driver Assistant. Summarize HOS time remaining, recent inspections, and relevant alerts concisely. Prefer actionable steps.';
        break;
      case 'ownerop':
        systemPrompt = 'You are an Owner-Operator Assistant. Summarize HOS, inspections, expenses and profit signals. Compute net CPM if possible.';
        break;
      case 'fleet_manager':
        systemPrompt = 'You are a Fleet Manager Assistant. Identify loads at late-ETA risk, match drivers to loads using HOS and routes, and summarize org KPIs.';
        break;
      case 'broker':
        systemPrompt = 'You are a Broker Assistant. Recommend best-fit carriers/drivers using routes, HOS, and risk hints. Explain reasoning briefly.';
        break;
    }

    // 3) Call LLM
    const model = 'gpt-4o-mini';
    const provider = 'openai';
    const aiResp = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${LLM_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: prompt },
          { role: 'system', content: 'Here is the structured context (truncate if large): ' + JSON.stringify(context).slice(0, 6000) },
        ],
        temperature: 0.2,
      }),
    });
    const aiJson = await aiResp.json();
    const answer = aiJson?.choices?.[0]?.message?.content ?? 'No response.';
    const latency_ms = Date.now() - t0;
    const tokens_prompt = aiJson?.usage?.prompt_tokens ?? null;
    const tokens_completion = aiJson?.usage?.completion_tokens ?? null;

    // 4) Audit log
    try {
      await sb.from('ai_audit_log').insert({
        org_id,
        user_id,
        role,
        plan_tier,
        provider,
        model,
        prompt,
        answer_excerpt: String(answer).slice(0, 512),
        tokens_prompt,
        tokens_completion,
        latency_ms,
        status: 'ok',
        metadata: { driver_user_id, load_id },
      });
    } catch (_e) {
      // ignore audit failure
    }

    return new Response(JSON.stringify({ answer }), { status: 200 });
  } catch (e) {
    const latency_ms = Date.now() - t0;
    // Best-effort audit error
    try {
      const { org_id, user_id, plan_tier } = getClaims(req);
      const body = await req.json().catch(() => ({}));
      await sb.from('ai_audit_log').insert({
        org_id: org_id || null,
        user_id: user_id || null,
        role: (body?.role as string) || 'driver',
        plan_tier: (plan_tier as Plan) || 'free',
        provider: 'openai',
        model: 'gpt-4o-mini',
        prompt: (body?.prompt as string) || '',
        answer_excerpt: null,
        tokens_prompt: null,
        tokens_completion: null,
        latency_ms,
        status: 'error',
        error: String(e),
        metadata: { driver_user_id: body?.driver_user_id, load_id: body?.load_id },
      });
    } catch { /* ignore */ }
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});