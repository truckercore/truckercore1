'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';

interface BillingStatus {
  isPremium: boolean;
  subscriptionStatus?: string;
  planCode?: string;
  premiumExpiresAt?: string;
  stripeCustomerId?: string;
}

export default function BillingStatusCard({ userId }: { userId?: string }) {
  const [status, setStatus] = useState<BillingStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [portalLoading, setPortalLoading] = useState(false);

  useEffect(() => {
    fetch('/api/billing/status')
      .then(r => r.json())
      .then(setStatus)
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const openPortal = async () => {
    setPortalLoading(true);
    try {
      const res = await fetch('/api/billing/portal', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ returnUrl: window.location.href }),
      });
      const data = await res.json();
      if (data.url) window.location.href = data.url;
      else alert(data.error || 'Billing portal unavailable');
    } catch {
      alert('Failed to open billing portal');
    } finally {
      setPortalLoading(false);
    }
  };

  const getPlanLabel = (planCode?: string) => {
    const labels: Record<string, string> = {
      driver_pro: 'Driver Pro',
      owner_operator_pro: 'Owner Operator Pro',
      fleet_basic: 'Fleet Basic',
      fleet_pro: 'Fleet Pro',
      broker_pro: 'Broker Pro',
    };
    return planCode ? (labels[planCode] || planCode) : 'Free Plan';
  };

  const getStatusColor = (subscriptionStatus?: string) => {
    if (subscriptionStatus === 'active') return 'text-green-400';
    if (subscriptionStatus === 'trialing') return 'text-blue-400';
    if (subscriptionStatus === 'past_due') return 'text-yellow-400';
    if (subscriptionStatus === 'canceled') return 'text-red-400';
    return 'text-gray-400';
  };

  if (loading) {
    return (
      <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4 animate-pulse">
        <div className="h-20 bg-gray-800 rounded-xl" />
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-bold text-white">💳 Billing & Plan</h3>
        {status?.isPremium && (
          <span className="bg-amber-500 text-black text-xs px-2 py-0.5 rounded-full font-bold">
            PRO
          </span>
        )}
      </div>

      <div className="space-y-3">
        <div className="flex justify-between items-center">
          <span className="text-gray-400 text-sm">Current Plan</span>
          <span className="text-white font-medium text-sm">
            {getPlanLabel(status?.planCode)}
          </span>
        </div>

        {status?.subscriptionStatus && (
          <div className="flex justify-between items-center">
            <span className="text-gray-400 text-sm">Status</span>
            <span className={`text-sm font-medium capitalize ${getStatusColor(status.subscriptionStatus)}`}>
              {status.subscriptionStatus}
            </span>
          </div>
        )}

        {status?.premiumExpiresAt && (
          <div className="flex justify-between items-center">
            <span className="text-gray-400 text-sm">Renews</span>
            <span className="text-white text-sm">
              {new Date(status.premiumExpiresAt).toLocaleDateString()}
            </span>
          </div>
        )}

        <div className="pt-2 space-y-2">
          {status?.isPremium ? (
            <button
              onClick={openPortal}
              disabled={portalLoading}
              className="w-full bg-gray-800 hover:bg-gray-700 disabled:opacity-40 text-white text-sm py-2 rounded-lg transition"
            >
              {portalLoading ? 'Opening...' : '⚙️ Manage Subscription'}
            </button>
          ) : (
            <Link
              href="/upgrade"
              className="block w-full bg-amber-500 hover:bg-amber-600 text-black text-sm font-bold py-2 rounded-lg transition text-center"
            >
              🚀 Upgrade to Pro
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}