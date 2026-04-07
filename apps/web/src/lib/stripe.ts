import Stripe from 'stripe';

// Factory function for use inside handlers
export function getStripe() {
  return new Stripe(process.env.STRIPE_SECRET_KEY!, {
    apiVersion: '2024-06-20',
  });
}

// Keep named export for backward compatibility with existing imports
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'dummy_key_for_build', {
  apiVersion: '2024-06-20',
});
