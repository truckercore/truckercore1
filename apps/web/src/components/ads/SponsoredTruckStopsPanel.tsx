'use client';

import { useSponsoredTruckStops } from '../../hooks/useSponsoredTruckStops';
import { MapPin, Navigation } from 'lucide-react';

export function SponsoredTruckStopsPanel() {
  const { ads, loading } = useSponsoredTruckStops();

  if (loading || ads.length === 0) return null;

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 mt-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-white font-bold flex items-center gap-2">
          <Navigation size={18} className="text-blue-500" />
          Nearby Stops & Deals
        </h2>
        <span className="text-xs text-gray-500 uppercase font-bold tracking-wider">Promoted</span>
      </div>
      <div className="space-y-4">
        {ads.map(ad => (
          <div key={ad.id} className="bg-gray-800 border border-gray-700 rounded-lg p-3 group hover:border-gray-600 transition">
            <div className="flex justify-between items-start mb-2">
              <div>
                <h4 className="text-white font-bold text-sm">{ad.name}</h4>
                <p className="text-gray-400 text-xs flex items-center gap-1">
                  <MapPin size={12} />
                  {ad.location}
                </p>
              </div>
              <span className="bg-blue-900/50 text-blue-300 text-[10px] px-1.5 py-0.5 rounded border border-blue-800/50">
                {ad.distance}
              </span>
            </div>
            <div className="flex items-center justify-between mt-3">
              <div className="flex gap-1">
                {ad.amenities.map(a => (
                  <span key={a} className="text-[10px] bg-gray-700 text-gray-300 px-1.5 py-0.5 rounded">
                    {a}
                  </span>
                ))}
              </div>
              <button className="text-blue-400 text-xs font-bold hover:text-blue-300">
                Details →
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
