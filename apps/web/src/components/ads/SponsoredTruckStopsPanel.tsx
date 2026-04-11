'use client';

import { trackAdEvent } from '@/lib/ads/trackAdEvent';
import { useAdImpression } from './useAdImpression';

interface Ad {
  id: string;
  title: string;
  description: string;
  link_url: string;
}

export function SponsoredTruckStopsPanel({ ads, driverId }: { ads?: Ad[], driverId?: string }) {
  // We track the first ad as the panel impression
  useAdImpression(ads?.[0]?.id, driverId);

  if (!ads || ads.length === 0) return null;

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
      <div className="px-5 py-3 border-b border-gray-800 flex justify-between items-center">
        <h2 className="font-bold text-sm">Nearby Partner Stops</h2>
        <span className="text-[10px] text-yellow-500 uppercase tracking-widest font-bold">Featured</span>
      </div>
      <div className="divide-y divide-gray-800">
        {ads.map(ad => (
          <a 
            key={ad.id}
            href={ad.link_url}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => trackAdEvent(ad.id, 'click', driverId)}
            className="block p-4 hover:bg-gray-800/50 transition group"
          >
            <div className="flex justify-between items-start mb-1">
              <h3 className="font-bold text-sm text-white group-hover:text-yellow-400">{ad.title}</h3>
              <span className="text-[10px] bg-gray-800 px-1.5 py-0.5 rounded text-gray-500">Ad</span>
            </div>
            <p className="text-gray-400 text-xs line-clamp-2">{ad.description}</p>
          </a>
        ))}
      </div>
    </div>
  );
}

export default SponsoredTruckStopsPanel;
