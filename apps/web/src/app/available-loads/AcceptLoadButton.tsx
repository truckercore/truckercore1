'use client';

import { useState } from 'react';

export function AcceptLoadButton({ loadId, driverId }: { loadId: string; driverId: string }) {
  const [loading, setLoading] = useState(false);
  const [accepted, setAccepted] = useState(false);

  const handleAccept = async () => {
    if (!confirm('Are you sure you want to accept this load?')) return;
    
    setLoading(true);
    try {
      const res = await fetch('/api/loads/accept', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loadId, driverId })
      });
      const data = await res.json();
      if (data.success) {
        setAccepted(true);
        window.location.href = '/driver-dashboard';
      } else {
        alert(data.error || 'Failed to accept load');
      }
    } catch (err) {
      console.error('Accept failed', err);
    } finally {
      setLoading(false);
    }
  };

  if (accepted) {
    return (
      <button disabled className="w-full bg-green-600/50 text-white rounded-lg py-2 text-sm font-medium transition cursor-not-allowed">
        ✅ Load Accepted
      </button>
    );
  }

  return (
    <button 
      onClick={handleAccept} 
      disabled={loading}
      className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800/50 rounded-lg py-2 text-sm font-medium transition"
    >
      {loading ? 'Accepting...' : 'Accept Load'}
    </button>
  );
}
