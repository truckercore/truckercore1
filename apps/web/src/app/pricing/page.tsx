'use client';

import { useState } from 'react';
import Link from 'next/link';

export default function PricingPage() {
  const [loading, setLoading] = useState<string | null>(null);

  const plans = [
    {
      id: 'free',
      name: 'Free',
      price: '$0',
      description: 'Core dashboard, status updates, and basic loads board.',
      features: ['Basic GPS Tracking', 'Manual HOS Logging', 'Standard Load Board', 'Community Support'],
      cta: 'Current Plan',
      isPremium: false,
    },
    {
      id: 'premium',
      name: 'Premium',
      price: '$49',
      priceSuffix: '/mo',
      description: 'Advanced intelligence for independent owner-operators.',
      features: [
        'Route Revenue Analytics', 
        'Automated HOS Violation Alerts', 
        'Sponsored Stop Discounts', 
        'Priority Load Support', 
        'Expense Tracking'
      ],
      cta: 'Go Premium',
      isPremium: true,
      popular: true,
    },
    {
      id: 'fleet',
      name: 'Fleet Manager',
      price: '$99',
      priceSuffix: '/mo per truck',
      description: 'Full visibility and coordination for growing carriers.',
      features: [
        'Multi-Truck GPS View', 
        'Driver Performance Scorecards', 
        'Broker/Carrier Integration', 
        'Fleet Maintenance Log', 
        'ELD/HOS Compliance API'
      ],
      cta: 'Contact Sales',
      isPremium: true,
    }
  ];

  const handleSubscribe = async (planId: string) => {
    if (planId === 'free') return;
    if (planId === 'fleet') { window.location.href = 'mailto:sales@truckercore.com'; return; }

    setLoading(planId);
    try {
      const res = await fetch('/api/billing/create-checkout-session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ priceId: planId === 'premium' ? 'price_premium_monthly' : 'price_fleet_monthly' })
      });
      const data = await res.json();
      if (data.url) {
        window.location.href = data.url;
      } else {
        alert(data.error || 'Failed to start checkout');
      }
    } catch (err) {
      console.error('Subscription failed', err);
    } finally {
      setLoading(null);
    }
  };

  return (
    <div className="min-h-screen bg-gray-950 text-white selection:bg-blue-500/30">
      <div className="max-w-6xl mx-auto px-4 py-16">
        <div className="text-center mb-16 space-y-4">
          <h1 className="text-4xl md:text-5xl font-black tracking-tight">Simple, Transparent Pricing</h1>
          <p className="text-gray-400 text-lg max-w-2xl mx-auto">Choose the plan that fits your operation. Scale as your fleet grows.</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {plans.map(plan => (
            <div 
              key={plan.id} 
              className={`relative flex flex-col p-8 rounded-2xl border transition-all duration-300 hover:scale-[1.02] ${
                plan.popular 
                  ? 'bg-gray-900 border-blue-500/50 shadow-[0_0_30px_rgba(59,130,246,0.15)] ring-1 ring-blue-500/30' 
                  : 'bg-gray-950 border-gray-800 hover:border-gray-700'
              }`}
            >
              {plan.popular && (
                <div className="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-blue-600 px-3 py-1 rounded-full text-[10px] uppercase font-black tracking-widest text-white ring-4 ring-gray-950">
                  Most Popular
                </div>
              )}

              <div className="mb-8">
                <h3 className="text-xl font-bold mb-2">{plan.name}</h3>
                <div className="flex items-baseline gap-1">
                  <span className="text-4xl font-black">{plan.price}</span>
                  {plan.priceSuffix && <span className="text-gray-500 text-sm">{plan.priceSuffix}</span>}
                </div>
                <p className="mt-4 text-gray-400 text-sm leading-relaxed">{plan.description}</p>
              </div>

              <div className="flex-1 space-y-4 mb-8">
                {plan.features.map(feature => (
                  <div key={feature} className="flex items-start gap-3 text-sm">
                    <span className="text-blue-500 mt-0.5">✓</span>
                    <span className="text-gray-300">{feature}</span>
                  </div>
                ))}
              </div>

              <button
                onClick={() => handleSubscribe(plan.id)}
                disabled={loading === plan.id || plan.id === 'free'}
                className={`w-full py-4 rounded-xl font-black text-sm uppercase tracking-widest transition-all ${
                  plan.id === 'free'
                    ? 'bg-gray-800 text-gray-500 cursor-default'
                    : plan.popular
                      ? 'bg-blue-600 hover:bg-blue-500 text-white shadow-lg shadow-blue-600/20'
                      : 'bg-white text-gray-950 hover:bg-gray-100'
                }`}
              >
                {loading === plan.id ? 'Loading...' : plan.cta}
              </button>
            </div>
          ))}
        </div>

        <div className="mt-16 text-center">
           <Link href="/driver-dashboard" className="text-gray-500 hover:text-white transition text-sm">← Back to Dashboard</Link>
        </div>
      </div>
    </div>
  );
}
