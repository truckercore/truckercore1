'use client';

import { useState, useEffect } from 'react';
import { TruckStopAd } from '../types/truckStopAds';

export function useSponsoredTruckStops() {
  const [ads, setAds] = useState<TruckStopAd[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Simulated fetch of sponsored truck stops
    const mockAds: TruckStopAd[] = [
      {
        id: '1',
        name: "Loves Travel Stop #452",
        location: "I-20 Exit 12, Weatherford, TX",
        distance: "12.4 mi",
        amenities: ["Showers", "DEF", "Arby's"],
        discount: "5¢ off/gal with TC Pay",
        imageUrl: "https://images.unsplash.com/photo-1545459720-aac273a27b3d?auto=format&fit=crop&w=800&q=80"
      },
      {
        id: '2',
        name: "Pilot Flying J #108",
        location: "I-35 Exit 221, Denton, TX",
        distance: "28.1 mi",
        amenities: ["Prime Parking", "Laundry", "Wendy's"],
        discount: "Free Coffee for TC Premium",
        imageUrl: "https://images.unsplash.com/photo-1545459720-aac273a27b3d?auto=format&fit=crop&w=800&q=80"
      }
    ];
    
    setAds(mockAds);
    setLoading(false);
  }, []);

  return { ads, loading };
}
