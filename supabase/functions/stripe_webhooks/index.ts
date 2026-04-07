import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

// Early environment validation
const required = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
];
const missing = required.filter((k) => !Deno.env.get(k));
if (missing.length) {
  console.error(`[startup] Missing required envs: ${missing.join(', ')}`);
  throw new Error('Configuration error: missing required environment variables');
}
const svc = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
if (!/^([A-Za-z0-9\.\-_]{20,})$/.test(svc)) {
  console.warn('[startup] SUPABASE_SERVICE_ROLE_KEY format looks unusual');
}

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

const PLAN_ENTITLEMENTS: Record<string,string[]> = {
  free: ['public_track'],
  pro:  ['public_track','ai_match','roi','safety','ifta','chat'],
  enterprise: ['public_track','ai_match','roi','safety','ifta','chat','priority_support'],
};

Deno.serve(async (req) => {
  try {
    // Optional: Stripe signature verification (simple HMAC SHA256 variant)
    const secret = Deno.env.get('STRIPE_WEBHOOK_SECRET');
    const sigHeader = req.headers.get('stripe-signature') || req.headers.get('Stripe-Signature');
    let event: any = null;
    const raw = await req.text();
    if (secret) {
      if (!sigHeader) return new Response(JSON.stringify({ error: 'missing stripe signature' }), { status: 400 });
      // Minimal verification: compute HMAC of body with secret and compare to header (assumes header contains the hex digest directly)
      const enc = new TextEncoder();
      const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
      const sig = await crypto.subtle.sign('HMAC', key, enc.encode(raw));
      const digestHex = Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2,'0')).join('');
      if (sigHeader.trim() !== digestHex) {
        return new Response(JSON.stringify({ error: 'invalid signature' }), { status: 400 });
      }
      event = JSON.parse(raw);
    } else {
      // No secret configured: accept JSON (staging/dev only)
      event = JSON.parse(raw || '{}');
    }

    // Idempotency: skip if event id already processed (best-effort; expects processed_events table)
    if (event?.id) {
      try {
        const { data: seen } = await sb.from('processed_events').select('id').eq('id', event.id).maybeSingle();
        if (seen) return new Response(JSON.stringify({ ok: true, duplicate: true }), { status: 200 });
      } catch (_) {}
    }

    // Branch: handle Stripe subscription.created/updated per new entitlements upsert contract
    const type = (event?.type as string) || '';
    const obj = event?.data?.object;
    if (type.startsWith('customer.subscription') || (obj?.object === 'subscription')) {
      const sub: any = obj || event?.data?.object || {};
      const orgId = (sub?.metadata?.org_id as string) || (sub?.metadata?.orgId as string) || null;
      const customerId = (sub?.customer as string | undefined);
      const accountId = (event as any)?.account as string | undefined; // present if using Connect

      const line = sub?.items?.data?.[0];
      const qty = Math.max(1, line?.quantity ?? 1);
      const price = line?.price;
      const nickname = price?.nickname as string | undefined;
      let plan: 'free' | 'pro' | 'enterprise' = 'free';
      const nick = (nickname || '').toLowerCase();
      if (nick.includes('pro')) plan = 'pro';
      else if (nick.includes('enterprise')) plan = 'enterprise';

      // Upsert with org_id conflict (guard if table has expected columns)
      if (!orgId) {
        return new Response(JSON.stringify({ error: 'ORG_ID_REQUIRED' }), { status: 400 });
      }
      const payload: Record<string, any> = {
        org_id: orgId,
        plan,
        seats: plan === 'pro' || plan === 'enterprise' ? qty : 1,
        customer_id: customerId ?? null,
        account_id: accountId ?? null,
        updated_at: new Date().toISOString(),
      };
      // Try to upsert into entitlements (org-scoped). If schema mismatch, fall back to legacy path below.
      const up = await sb.from('entitlements').upsert(payload as any, { onConflict: 'org_id' });
      if (up.error) {
        // Fall back to legacy behavior if entitlements schema is feature-based
        // Resolve account_id + plan for legacy tables
        const legacy_account_id = (event.account_id || event.customer || event.client_reference_id) as string;
        const legacy_plan = plan;
        const period_end = new Date(sub?.current_period_end ? sub.current_period_end * 1000 : Date.now());
        if (!legacy_account_id) {
          return new Response(JSON.stringify({ error: 'account_id required' }), { status: 400 });
        }
        const { error: subErr } = await sb.from('subscriptions').upsert({
          account_id: legacy_account_id,
          plan: legacy_plan,
          status: 'active',
          current_period_end: period_end.toISOString()
        }, { onConflict: 'account_id' });
        if (subErr) return new Response(JSON.stringify({ error: subErr.message }), { status: 500 });
        const feats = PLAN_ENTITLEMENTS[legacy_plan] ?? PLAN_ENTITLEMENTS.free;
        const { error: delErr } = await sb.from('entitlements').delete().eq('account_id', legacy_account_id);
        if (delErr) return new Response(JSON.stringify({ error: delErr.message }), { status: 500 });
        const rows = feats.map((f) => ({ account_id: legacy_account_id, feature: f, enabled: true }));
        const { error: insErr } = await sb.from('entitlements').insert(rows);
        if (insErr) return new Response(JSON.stringify({ error: insErr.message }), { status: 500 });
      }

      // Mark event processed (best-effort)
      if (event?.id) {
        try { await sb.from('processed_events').insert({ id: event.id, kind: 'stripe' }); } catch (_) {}
      }
      try { await sb.from('metrics_events').insert({ kind: 'webhook_stripe_ok', props: { org_id: orgId, plan } }); } catch (_) {}
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }

    // Legacy generic handler (kept for backward-compat inputs)
    // Resolve account_id + plan + period_end from evt
    const account_id = (event.account_id || event.customer || event.client_reference_id) as string; // map from customer/org
    const plan = (event.plan as string) ?? 'free';
    const period_end = new Date(event.current_period_end || Date.now());
    if (!account_id) {
      return new Response(JSON.stringify({ error: 'account_id required' }), { status: 400 });
    }

    const { error: subErr } = await sb.from('subscriptions').upsert({
      account_id,
      plan,
      status: 'active',
      current_period_end: period_end.toISOString()
    }, { onConflict: 'account_id' });
    if (subErr) return new Response(JSON.stringify({ error: subErr.message }), { status: 500 });

    const feats = PLAN_ENTITLEMENTS[plan] ?? PLAN_ENTITLEMENTS.free;
    const { error: delErr } = await sb.from('entitlements').delete().eq('account_id', account_id);
    if (delErr) return new Response(JSON.stringify({ error: delErr.message }), { status: 500 });

    const rows = feats.map((f) => ({ account_id, feature: f, enabled: true }));
    const { error: insErr } = await sb.from('entitlements').insert(rows);
    if (insErr) return new Response(JSON.stringify({ error: insErr.message }), { status: 500 });

    // Mark event processed (best-effort)
    if (event?.id) {
      try { await sb.from('processed_events').insert({ id: event.id, kind: 'stripe' }); } catch (_) {}
    }

    // Metrics: record webhook success
    try { await sb.from('metrics_events').insert({ kind: 'webhook_stripe_ok', props: { account_id, plan } }); } catch (_) {}
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e:any) {
    return new Response(JSON.stringify({ error: e?.message || 'webhook error' }), { status: 500 });
  }
});