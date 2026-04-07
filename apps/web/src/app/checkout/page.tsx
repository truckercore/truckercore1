"use client";
import React, { useState } from 'react';
import { useSearchParams } from 'next/navigation';

export default function CheckoutPage() {
  const params = useSearchParams();
  const [loading, setLoading] = useState(false);
  const [plan, setPlan] = useState<'pro' | 'enterprise'>('pro');

  const handleCheckout = async () => {
    const email = typeof window !== 'undefined' ? window.localStorage.getItem('user_email') : null;
    const orgId = typeof window !== 'undefined' ? (window.localStorage.getItem('org_id') || window.localStorage.getItem('orgId')) : null;
    if (!email || !orgId) {
      alert('Please sign in first');
      return;
    }

    setLoading(true);
    const referrerCode = params.get('ref') || undefined;
    const utmSource = params.get('utm_source') || undefined;
    const utmCampaign = params.get('utm_campaign') || undefined;

    const res = await fetch('/api/stripe/create-checkout-session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ plan, orgId, email, referrerCode, utmSource, utmCampaign }),
    });
    const { url, error } = await res.json();
    setLoading(false);

    if (error || !url) {
      alert(`Error: ${error || 'Unable to start checkout'}`);
      return;
    }

    window.location.href = url;
  };

  return (
    <div style={{ padding: 48, maxWidth: 600, margin: '0 auto' }}>
      <h1>Upgrade to Premium</h1>
      <p>Unlock full alerting, compliance automation, and analytics.</p>

      <div style={{ display: 'flex', gap: 24, marginTop: 24 }}>
        <Card
          title="Pro"
          price="$49/mo"
          features={['Unlimited alerts', 'CSV exports', 'Priority support']}
          selected={plan === 'pro'}
          onSelect={() => setPlan('pro')}
        />
        <Card
          title="Enterprise"
          price="$149/mo"
          features={['All Pro features', 'Fleet analytics', 'SSO ready', 'Dedicated support']}
          selected={plan === 'enterprise'}
          onSelect={() => setPlan('enterprise')}
        />
      </div>

      <button
        onClick={handleCheckout}
        disabled={loading}
        style={{
          marginTop: 32,
          padding: '12px 24px',
          fontSize: 16,
          cursor: loading ? 'not-allowed' : 'pointer',
          backgroundColor: '#58A6FF',
          color: '#fff',
          border: 'none',
          borderRadius: 8,
        }}
      >
        {loading ? 'Loading...' : `Subscribe to ${plan === 'pro' ? 'Pro' : 'Enterprise'}`}
      </button>
    </div>
  );
}

function Card({ title, price, features, selected, onSelect }: any) {
  return (
    <div
      onClick={onSelect}
      style={{
        flex: 1,
        padding: 24,
        border: selected ? '2px solid #58A6FF' : '1px solid #ccc',
        borderRadius: 8,
        cursor: 'pointer',
        backgroundColor: selected ? '#f0f8ff' : '#fff',
      }}
    >
      <h3>{title}</h3>
      <p style={{ fontSize: 24, fontWeight: 'bold', margin: '12px 0' }}>{price}</p>
      <ul>
        {features.map((f: string) => (
          <li key={f}>{f}</li>
        ))}
      </ul>
    </div>
  );
}
