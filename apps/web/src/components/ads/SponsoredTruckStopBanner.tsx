'use client';

import { trackAdEvent } from '@/lib/ads/trackAdEvent';
import { useAdImpression } from './useAdImpression';

interface Ad {
  id: string;
  title: string;
  image_url: string;
  link_url: string;
  description: string;
}

export function SponsoredTruckStopBanner({ ad, driverId }: { ad?: Ad, driverId?: string }) {
  useAdImpression(ad?.id, driverId);

  if (!ad) return null;

  return (
    <a 
      href={ad.link_url} 
      target="_blank" 
      rel="noopener noreferrer"
      onClick={() => trackAdEvent(ad.id, 'click', driverId)}
      className="block relative overflow-hidden rounded-xl border border-yellow-500/30 bg-gray-900 group"
    >
      <div className="flex flex-col md:flex-row items-center p-4 gap-4">
        <div className="w-20 h-20 bg-gray-800 rounded-lg flex-shrink-0 flex items-center justify-center border border-gray-700">
           <span className="text-2xl">⛽</span>
        </div>
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-[10px] uppercase tracking-wider bg-yellow-500/20 text-yellow-500 px-1.5 py-0.5 rounded font-bold">Sponsored</span>
            <h3 className="font-bold text-lg text-white group-hover:text-yellow-400 transition-colors">{ad.title}</h3>
          </div>
          <p className="text-gray-400 text-sm">{ad.description}</p>
        </div>
        <div className="px-4 py-2 bg-yellow-600 hover:bg-yellow-500 text-gray-950 font-bold rounded-lg transition text-sm">
          Visit Stop
        </div>
      </div>
    </a>
  );
}

export default SponsoredTruckStopBanner;
