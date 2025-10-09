/* Express Stripe webhook for seat sync */
import express from 'express';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';

const app = express();
// Raw body is needed for signature verification
app.use(express.raw({ type: 'application/json' }));

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, { apiVersion: '2023-10-16' });
const supa = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

app.post('/stripe/webhook', async (req, res) => {
  const sig = req.headers['stripe-signature'];
  try {
    const evt = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);

    if (evt.type === 'customer.subscription.updated' || evt.type === 'customer.subscription.created') {
      const sub = evt.data.object;
      const customer = sub.customer;
      // Assuming seats are set via quantity on a specific item
      const item = sub.items?.data?.[0];
      const seats = item?.quantity || 0;

      if (!customer || !seats) return res.json({ ok: true, note: 'no seats change' });

      const { data: org, error: orgErr } = await supa
        .from('orgs')
        .select('id, seats_total')
        .eq('stripe_customer_id', customer)
        .single();

      if (orgErr || !org) return res.status(404).json({ ok: false, error: 'org_not_found' });

      const { error: updErr } = await supa
        .from('orgs')
        .update({ seats_total: seats, updated_at: new Date().toISOString() })
        .eq('id', org.id);

      if (updErr) return res.status(500).json({ ok: false, error: updErr.message });

      return res.json({ ok: true, org_id: org.id, seats_total: seats });
    }

    return res.json({ ok: true, ignored: evt.type });
  } catch (e) {
    return res.status(400).send(`Webhook Error: ${e.message}`);
  }
});

app.listen(process.env.PORT || 3000, () => console.log('Stripe webhook listening'));
