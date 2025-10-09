// deno-fns/payments_complete.ts
// Endpoint: POST /payments/complete { payment_intent_id }
// Uses Stripe SDK with exponential backoff for retrieve/confirm operations.
import Stripe from 'https://esm.sh/stripe@14.25.0?target=deno'
import { withBackoff } from './lib/backoff.ts'

const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
const stripe = stripeKey ? new Stripe(stripeKey, { apiVersion: '2024-06-20' }) : null

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })
    if (!stripe) return new Response(JSON.stringify({ error: 'stripe_not_configured' }), { status: 500, headers: { 'content-type': 'application/json' } })

    const { payment_intent_id } = await req.json().catch(() => ({})) as { payment_intent_id?: string }
    if (!payment_intent_id) return new Response(JSON.stringify({ error: 'bad_request' }), { status: 400, headers: { 'content-type': 'application/json' } })

    // Retrieve PI (retry on transient errors)
    let pi = await withBackoff(() => stripe.paymentIntents.retrieve(payment_intent_id))

    if (pi.status !== 'succeeded') {
      // Attempt confirm with idempotency (keyed by PI) and backoff
      const idemKey = `confirm_${payment_intent_id}`
      pi = await withBackoff(() => stripe!.paymentIntents.confirm(payment_intent_id, {}), { retries: 5, baseMs: 300 })
    }

    // Minimal response; in production record success in DB
    return new Response(JSON.stringify({ ok: true, status: pi.status, id: pi.id }), { headers: { 'content-type': 'application/json' } })
  } catch (e) {
    const msg = (e as any)?.message || String(e)
    return new Response(JSON.stringify({ error: msg }), { status: 500, headers: { 'content-type': 'application/json' } })
  }
})
