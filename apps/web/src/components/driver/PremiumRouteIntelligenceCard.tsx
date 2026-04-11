'use client';

import { Zap, Crown } from 'lucide-react';

interface PremiumRouteIntelligenceCardProps {
  isPremium: boolean;
}

export function PremiumRouteIntelligenceCard({ isPremium }: PremiumRouteIntelligenceCardProps) {
  if (!isPremium) {
    return (
      <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 relative overflow-hidden">
        <div className="absolute top-0 right-0 bg-yellow-600/20 text-yellow-500 text-[10px] font-bold px-2 py-1 rounded-bl-lg flex items-center gap-1">
          <Crown size={10} />
          PREMIUM
        </div>
        <h3 className="text-white font-bold mb-2 flex items-center gap-2">
          <Zap size={18} className="text-yellow-500" />
          Route Intelligence
        </h3>
        <p className="text-gray-400 text-sm mb-4">
          Unlock real-time traffic, weather alerts, and optimized fuel stops along your route.
        </p>
        <button className="w-full bg-yellow-600 hover:bg-yellow-700 text-white font-bold py-2 rounded-lg text-sm transition">
          Upgrade to Premium
        </button>
      </div>
    );
  }

  return (
    <div className="bg-gradient-to-br from-gray-900 to-yellow-900/10 border border-yellow-900/50 rounded-xl p-5">
      <h3 className="text-white font-bold mb-2 flex items-center gap-2">
        <Zap size={18} className="text-yellow-500" />
        Route Intelligence
      </h3>
      <div className="space-y-3 mt-4">
        <div className="bg-gray-800/50 p-2 rounded-lg flex items-center justify-between">
          <span className="text-xs text-gray-300">Congestion ahead (I-35)</span>
          <span className="text-[10px] bg-red-900 text-red-300 px-1.5 py-0.5 rounded">+15m delay</span>
        </div>
        <div className="bg-gray-800/50 p-2 rounded-lg flex items-center justify-between">
          <span className="text-xs text-gray-300">Weather: Heavy Rain expected</span>
          <span className="text-[10px] bg-blue-900 text-blue-300 px-1.5 py-0.5 rounded">In 45 mi</span>
        </div>
      </div>
    </div>
  );
}
