'use client';

import { Bell, Clock, Crown } from 'lucide-react';

interface PremiumHOSAlertsCardProps {
  isPremium: boolean;
  hosLeft: number;
}

export function PremiumHOSAlertsCard({ isPremium, hosLeft }: PremiumHOSAlertsCardProps) {
  if (!isPremium) {
    return (
      <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 mt-4 relative">
        <h3 className="text-white font-bold mb-2 flex items-center gap-2">
          <Bell size={18} className="text-gray-400" />
          HOS Predictive Alerts
        </h3>
        <p className="text-gray-500 text-sm mb-4 italic">
          Standard: Notifications 30m before violation.
        </p>
        <div className="bg-gray-800 rounded-lg p-3 text-center border border-dashed border-gray-700">
           <p className="text-[10px] text-gray-500">Premium includes smart rest suggestions and local parking availability.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-gray-900 border border-yellow-900/30 rounded-xl p-5 mt-4">
      <div className="flex justify-between items-start mb-4">
        <h3 className="text-white font-bold flex items-center gap-2">
          <Clock size={18} className="text-yellow-500" />
          HOS Intelligence
        </h3>
        <span className="text-[10px] bg-yellow-600/20 text-yellow-500 px-1.5 py-0.5 rounded flex items-center gap-1">
          <Crown size={8} /> PREMIUM
        </span>
      </div>
      <div className="bg-green-900/20 border border-green-800/50 rounded-lg p-3">
        <p className="text-green-300 text-xs font-bold mb-1">Optimal Break Window</p>
        <p className="text-green-100 text-[10px]">
          Suggested rest in 2.5 hrs at Pilot #108 (12 spots left).
        </p>
      </div>
    </div>
  );
}
