'use client';

import { useSponsoredTruckStops } from '../../hooks/useSponsoredTruckStops';
import { Tag } from 'lucide-react';

export function SponsoredTruckStopBanner() {
  const { ads, loading } = useSponsoredTruckStops();

  if (loading || ads.length === 0) return null;

  const featured = ads[0];

  return (
    <div className="bg-gradient-to-r from-blue-900 to-indigo-900 border border-blue-800 rounded-xl p-4 flex items-center justify-between gap-4">
      <div className="flex items-center gap-3">
        <div className="bg-blue-600 p-2 rounded-lg">
          <Tag className="text-white" size={20} />
        </div>
        <div>
          <p className="text-xs text-blue-200 uppercase font-bold tracking-wider">Sponsored Deal</p>
          <h3 className="text-white font-bold">{featured.name}</h3>
          <p className="text-blue-100 text-sm">{featured.discount}</p>
        </div>
      </div>
      <button className="bg-white text-blue-900 px-4 py-2 rounded-lg text-sm font-bold hover:bg-blue-50 transition">
        Get Deal
      </button>
    </div>
  );
}
