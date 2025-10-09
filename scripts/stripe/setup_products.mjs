// scripts/stripe/setup_products.mjs
// Setup Stripe products and prices
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, { apiVersion: '2023-10-16' });

async function main() {
  console.log('[stripe] Creating products and prices...');

  // Pro Plan
  const proProd = await stripe.products.create({
    name: 'TruckerCore Pro',
    description: 'Full alerting, exports, compliance automation',
    metadata: { plan: 'pro' },
  });
  const proPrice = await stripe.prices.create({
    product: proProd.id,
    unit_amount: 4900, // $49.00/mo
    currency: 'usd',
    recurring: { interval: 'month' },
    metadata: { plan: 'pro' },
  });
  console.log(`Pro: product=${proProd.id}, price=${proPrice.id}`);

  // Enterprise Plan
  const entProd = await stripe.products.create({
    name: 'TruckerCore Enterprise',
    description: 'Fleet analytics, advanced compliance, SSO',
    metadata: { plan: 'enterprise' },
  });
  const entPrice = await stripe.prices.create({
    product: entProd.id,
    unit_amount: 14900, // $149.00/mo
    currency: 'usd',
    recurring: { interval: 'month' },
    metadata: { plan: 'enterprise' },
  });
  console.log(`Enterprise: product=${entProd.id}, price=${entPrice.id}`);

  console.log('\n✅ Stripe setup complete. Update your .env:');
  console.log(`STRIPE_PRICE_PRO=${proPrice.id}`);
  console.log(`STRIPE_PRICE_ENTERPRISE=${entPrice.id}`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});