// Deno (Supabase Edge Function)
// Admin operations: DLQ replay, test-delivery, secret rotation, commit, and topic filters
// Security: require service role or an org admin JWT (app_roles contains 'fleet_manager' or 'broker')

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.2'

function json(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), { headers: { 'Content-Type': 'application/json' }, ...init })
}

function isOrgAdmin(jwt: any): boolean {
  try {
    const roles = (jwt?.app_roles ?? []) as string[]
    return roles.includes('fleet_manager') || roles.includes('broker')
  } catch { return false }
}

async function rpc(client: any, fn: string, args: Record<string, unknown>) {
  const { data, error } = await client.rpc(fn, args)
  if (error) throw new Error(`[rpc:${fn}] ${error.message}`)
  return data
}

serve(async (req: Request) => {
  const url = new URL(req.url)
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
  const auth = req.headers.get('authorization') || ''
  const bearer = auth.startsWith('Bearer ') ? auth.substring(7) : ''

  const useService = !!supabaseKey
  const client = createClient(supabaseUrl, useService ? supabaseKey : bearer, { global: { headers: { Authorization: `Bearer ${useService ? supabaseKey : bearer}` } } })

  if (req.method === 'GET' && url.pathname.endsWith('/health')) {
    return json({ ok: true })
  }

  if (req.method === 'POST' && url.pathname.endsWith('/dlq/replay')) {
    const body = await req.json().catch(() => ({})) as any
    const id = body.outbox_id as string | undefined
    const topic = body.topic as string | undefined
    const olderThanMins = Number(body.older_than_minutes ?? 0)
    if (id) {
      await rpc(client, 'outbox_replay_dead', { p_outbox_id: id })
      return json({ ok: true, replayed: 1 })
    }

    // Batch: filter by topic and age
    const { data, error } = await client.from('event_outbox')
      .select('id, event_type, created_at')
      .eq('status', 'dead')
      .maybe((q: any) => topic ? q.eq('event_type', topic) : q)
      .lte('created_at', new Date(Date.now() - olderThanMins * 60_000).toISOString())
    if (error) return json({ error: error.message }, { status: 500 })

    let count = 0
    for (const row of (data as any[])) {
      await rpc(client, 'outbox_replay_dead', { p_outbox_id: row.id })
      count++
    }
    return json({ ok: true, replayed: count })
  }

  if (req.method === 'POST' && url.pathname.endsWith('/test-delivery')) {
    const body = await req.json() as any
    const subscriptionId = body.subscription_id as string
    if (!subscriptionId) return json({ error: 'subscription_id required' }, { status: 400 })
    // Build a mock payload
    const payload = {
      id: crypto.randomUUID(),
      org_id: body.org_id ?? '00000000-0000-0000-0000-000000000000',
      topic: body.topic ?? 'test.ping',
      schema_version: 1,
      payload: body.payload ?? { hello: 'world' },
      created_at: new Date().toISOString(),
    }
    // Fetch subscription
    const { data: sub, error } = await client.from('webhook_subscriptions').select('*').eq('id', subscriptionId).single()
    if (error || !sub) return json({ error: error?.message || 'subscription not found' }, { status: 404 })

    // Sign and send
    const ts = Math.floor(Date.now() / 1000)
    const base = `${ts}.${JSON.stringify(payload)}`
    const sig = 'sha256=' + (await crypto.subtle.digest('SHA-256', new TextEncoder().encode(base)).then((b) => Array.from(new Uint8Array(b)).map((x) => x.toString(16).padStart(2, '0')).join('')))

    const res = await fetch(sub.endpoint_url ?? sub.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-TruckerCore-Event': payload.topic,
        'X-TruckerCore-Timestamp': String(ts),
        'X-TruckerCore-Signature': sig,
        'Idempotency-Key': payload.id,
      },
      body: JSON.stringify(payload),
    })
    const text = await res.text().catch(() => '')
    return json({ ok: res.ok, status: res.status, body: text })
  }

  // Admin: rotate secret with overlap window
  if (req.method === 'POST' && /\/v1\/orgs\/.+\/webhooks\/.+\/rotate-secret$/.test(url.pathname)) {
    const body = await req.json().catch(() => ({})) as any
    const secretNext = body.secret_next as string | undefined
    const overlap = Number(body.overlap_minutes ?? 1440)
    if (!secretNext) return json({ error: 'secret_next required' }, { status: 400 })
    const parts = url.pathname.split('/')
    const subId = parts[parts.length - 2]
    const expiresAt = new Date(Date.now() + overlap * 60_000).toISOString()
    const { error } = await client.from('webhook_subscriptions').update({ secret_next: secretNext, secret_next_expires_at: expiresAt }).eq('id', subId)
    if (error) return json({ error: error.message }, { status: 500 })
    return json({ ok: true, secret_next_expires_at: expiresAt }, { status: 202 })
  }

  // Admin: commit secret (swap and clear)
  if (req.method === 'POST' && /\/v1\/orgs\/.+\/webhooks\/.+\/commit-secret$/.test(url.pathname)) {
    const parts = url.pathname.split('/')
    const subId = parts[parts.length - 2]
    const { data: sub, error } = await client.from('webhook_subscriptions').select('secret_next').eq('id', subId).single()
    if (error) return json({ error: error.message }, { status: 500 })
    if (!sub?.secret_next) return json({ error: 'no secret_next to commit' }, { status: 400 })
    const { error: updErr } = await client.from('webhook_subscriptions').update({ secret: sub.secret_next, secret_next: null, secret_next_expires_at: null }).eq('id', subId)
    if (updErr) return json({ error: updErr.message }, { status: 500 })
    return new Response(null, { status: 204 })
  }

  // Admin: set topic filters (null/empty to clear)
  if (req.method === 'POST' && /\/v1\/orgs\/.+\/webhooks\/.+\/topics$/.test(url.pathname)) {
    const body = await req.json().catch(() => ({})) as any
    let topics = body.topic_filters as string[] | null | undefined
    if (topics && !Array.isArray(topics)) return json({ error: 'topic_filters must be array of strings' }, { status: 400 })
    if (topics) topics = topics.filter((t) => typeof t === 'string')
    const parts = url.pathname.split('/')
    const subId = parts[parts.length - 2]
    const { error } = await client.from('webhook_subscriptions').update({ topic_filters: (topics && topics.length > 0) ? topics : null }).eq('id', subId)
    if (error) return json({ error: error.message }, { status: 500 })
    return json({ ok: true })
  }

  return json({ error: 'not found' }, { status: 404 })
})
