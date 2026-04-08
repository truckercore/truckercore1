'use client';

import { useState, useEffect, useCallback } from 'react';
import nextDynamic from 'next/dynamic';
import { createClient } from '@/lib/supabase/client';

const LiveTrackingMap = nextDynamic(
  () => import('@/components/gps/LiveTrackingMap'),
  {
    ssr: false,
    loading: () => (
      <div className="w-full h-full flex items-center justify-center bg-gray-900">
        <div className="text-white animate-pulse">Loading map...</div>
      </div>
    ),
  }
);

interface Truck {
  vehicle_id: string;
  driver_name: string;
  latitude: number;
  longitude: number;
  speed_mph: number;
  heading: number;
  status: string;
  updated_at: string;
  origin_address?: string;
  destination_address?: string;
  route_geometry?: { coordinates: [number, number][] };
  distance_miles?: number;
  duration_minutes?: number;
}

const STATUS_CONFIG: Record<string, { label: string; color: string; dot: string }> = {
  en_route:    { label: 'En Route',    color: 'bg-blue-900/30 text-blue-400 border-blue-800', dot: 'bg-blue-400' },
  at_pickup:   { label: 'At Pickup',   color: 'bg-yellow-900/30 text-yellow-400 border-yellow-800', dot: 'bg-yellow-400' },
  at_delivery: { label: 'At Delivery', color: 'bg-green-900/30 text-green-400 border-green-800',  dot: 'bg-green-400' },
  idle:        { label: 'Idle',        color: 'bg-gray-800/30 text-gray-400 border-gray-700',    dot: 'bg-gray-400' },
  offline:     { label: 'Offline',     color: 'bg-red-900/30 text-red-400 border-red-800',      dot: 'bg-red-400' },
  rerouting:   { label: 'Rerouting',   color: 'bg-orange-900/30 text-orange-400 border-orange-800', dot: 'bg-orange-400' },
};

export default function GPSPageClient() {
  const [trucks, setTrucks] = useState<Truck[]>([]);
  const [selected, setSelected] = useState<Truck | null>(null);
  const [filter, setFilter] = useState('all');
  const [lastUpdate, setLastUpdate] = useState(new Date());

  const loadTrucks = useCallback(async () => {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('vehicle_current_positions')
      .select('*');
    if (data) {
      setTrucks(data as Truck[]);
      setLastUpdate(new Date());
    }
    if (error) console.error('GPS load error:', error);
  }, []);

  useEffect(() => {
    loadTrucks();

    const supabase = createClient();
    const channel = supabase
      .channel('gps-dispatch')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'vehicle_locations',
      }, async (payload) => {
        const row = payload.new as { vehicle_id?: string } | null;
        const vehicleId = row?.vehicle_id;
        if (!vehicleId) return;

        // Fetch only the changed truck from the route-aware view
        const { data, error } = await supabase
          .from('vehicle_current_positions')
          .select('*')
          .eq('vehicle_id', vehicleId)
          .maybeSingle();

        if (error) { console.error('GPS patch error:', error); return; }
        if (!data) { console.warn(`No position for ${vehicleId}`); return; }

        // Patch only the changed truck
        setTrucks(prev => {
          const next = [...prev];
          const index = next.findIndex(t => t.vehicle_id === data.vehicle_id);
          if (index >= 0) {
            next[index] = data as Truck;
          } else {
            next.push(data as Truck);
          }
          return next;
        });

        setLastUpdate(new Date());

        // Keep selected truck synced
        setSelected(prev => {
          if (!prev || prev.vehicle_id !== data.vehicle_id) return prev;
          return data as Truck;
        });
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [loadTrucks]);

  const filtered = filter === 'all'
    ? trucks
    : trucks.filter(t => t.status === filter);

  const stats = {
    total: trucks.length,
    en_route: trucks.filter(t => t.status === 'en_route').length,
    at_pickup: trucks.filter(t => t.status === 'at_pickup').length,
    at_delivery: trucks.filter(t => t.status === 'at_delivery').length,
    idle: trucks.filter(t => t.status === 'idle').length,
    offline: trucks.filter(t => t.status === 'offline').length,
  };

  return (
    <div className="h-screen flex flex-col bg-gray-950 overflow-hidden text-gray-100">
      {/* Header */}
      <header className="bg-gray-900 border-b border-gray-800 px-6 py-3 flex justify-between items-center z-20">
        <div className="flex items-center gap-4">
          <h1 className="text-xl font-bold bg-gradient-to-r from-blue-400 to-indigo-400 bg-clip-text text-transparent">
            Fleet Dispatch Board
          </h1>
          <div className="h-4 w-px bg-gray-700" />
          <div className="flex items-center gap-2 text-sm text-gray-400">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
            </span>
            Live Updates (Last: {lastUpdate.toLocaleTimeString()})
          </div>
        </div>
        <div className="flex gap-4 items-center">
          <div className="flex bg-gray-800 rounded-lg p-1 text-xs">
            <button 
              onClick={() => setFilter('all')}
              className={`px-3 py-1 rounded-md transition ${filter === 'all' ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-400 hover:text-gray-200'}`}
            >
              All ({stats.total})
            </button>
            <button 
              onClick={() => setFilter('en_route')}
              className={`px-3 py-1 rounded-md transition ${filter === 'en_route' ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-400 hover:text-gray-200'}`}
            >
              En Route ({stats.en_route})
            </button>
            <button 
              onClick={() => setFilter('offline')}
              className={`px-3 py-1 rounded-md transition ${filter === 'offline' ? 'bg-red-600 text-white shadow-lg' : 'text-gray-400 hover:text-gray-200'}`}
            >
              Offline ({stats.offline})
            </button>
          </div>
        </div>
      </header>

      <main className="flex-1 flex overflow-hidden">
        {/* Sidebar */}
        <aside className="w-80 border-r border-gray-800 bg-gray-900 flex flex-col z-10">
          <div className="p-4 border-b border-gray-800 bg-gray-900/50">
            <div className="grid grid-cols-2 gap-2 text-[10px] uppercase font-bold text-gray-500">
              <div className="bg-gray-800/50 p-2 rounded border border-gray-700/50">
                <div className="text-blue-400">Active</div>
                <div className="text-xl text-gray-100">{stats.en_route + stats.at_pickup + stats.at_delivery}</div>
              </div>
              <div className="bg-gray-800/50 p-2 rounded border border-gray-700/50">
                <div className="text-gray-400">Total</div>
                <div className="text-xl text-gray-100">{stats.total}</div>
              </div>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto custom-scrollbar">
            {filtered.length === 0 ? (
              <div className="p-8 text-center text-gray-500 italic text-sm">
                No vehicles matching filter
              </div>
            ) : (
              <div className="divide-y divide-gray-800/50">
                {filtered.map(truck => {
                  const config = STATUS_CONFIG[truck.status] || STATUS_CONFIG.idle;
                  const isSelected = selected?.vehicle_id === truck.vehicle_id;
                  
                  return (
                    <div 
                      key={truck.vehicle_id}
                      onClick={() => setSelected(truck)}
                      className={`p-4 cursor-pointer transition-all duration-200 hover:bg-gray-800/50 group ${
                        isSelected ? 'bg-blue-900/20 border-l-2 border-blue-500' : 'border-l-2 border-transparent'
                      }`}
                    >
                      <div className="flex justify-between items-start mb-1">
                        <span className="font-mono font-bold text-blue-400">{truck.vehicle_id}</span>
                        <span className={`text-[10px] px-2 py-0.5 rounded-full border ${config.color}`}>
                          {config.label}
                        </span>
                      </div>
                      <div className="text-sm font-medium text-gray-200">{truck.driver_name}</div>
                      <div className="mt-2 flex items-center justify-between text-xs text-gray-500">
                        <div className="flex items-center gap-1.5">
                          <div className={`h-1.5 w-1.5 rounded-full ${config.dot}`} />
                          {truck.speed_mph} mph • {truck.heading}°
                        </div>
                        <div className="group-hover:text-blue-400 transition-colors">
                          {isSelected ? 'Viewing →' : 'Details'}
                        </div>
                      </div>
                      
                      {isSelected && (
                        <div className="mt-3 pt-3 border-t border-gray-800/50 space-y-2 animate-in fade-in slide-in-from-top-1 duration-300">
                          <div className="text-[10px] text-gray-500">
                            <div className="flex justify-between">
                              <span>Origin:</span>
                              <span className="text-gray-300 truncate ml-2">{truck.origin_address || 'N/A'}</span>
                            </div>
                            <div className="flex justify-between mt-1">
                              <span>Dest:</span>
                              <span className="text-gray-300 truncate ml-2">{truck.destination_address || 'N/A'}</span>
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </aside>

        {/* Map Area */}
        <section className="flex-1 relative bg-[#1a1a2e]">
          <LiveTrackingMap 
            trucks={trucks} 
            selected={selected} 
            onSelectTruck={setSelected} 
          />
          
          {selected && (
            <div className="absolute bottom-6 right-6 z-[1000] bg-gray-900/95 border border-gray-700 p-4 rounded-xl shadow-2xl backdrop-blur-md max-w-sm animate-in slide-in-from-bottom-4 duration-300">
              <div className="flex justify-between items-center mb-3">
                <h3 className="font-bold text-blue-400">{selected.vehicle_id} - {selected.driver_name}</h3>
                <button 
                  onClick={() => setSelected(null)}
                  className="text-gray-500 hover:text-white"
                >
                  ✕
                </button>
              </div>
              <div className="grid grid-cols-2 gap-4 text-xs">
                <div>
                  <div className="text-gray-500 mb-1">Status</div>
                  <div className="font-semibold">{STATUS_CONFIG[selected.status]?.label || selected.status}</div>
                </div>
                <div>
                  <div className="text-gray-500 mb-1">Speed</div>
                  <div className="font-semibold">{selected.speed_mph} MPH</div>
                </div>
                {selected.distance_miles && (
                  <div>
                    <div className="text-gray-500 mb-1">Remaining Dist</div>
                    <div className="font-semibold text-blue-400">{selected.distance_miles.toFixed(1)} mi</div>
                  </div>
                )}
                {selected.duration_minutes && (
                  <div>
                    <div className="text-gray-500 mb-1">ETA</div>
                    <div className="font-semibold text-blue-400">{selected.duration_minutes} min</div>
                  </div>
                )}
              </div>
            </div>
          )}
        </section>
      </main>

      <style jsx global>{`
        .custom-scrollbar::-webkit-scrollbar {
          width: 4px;
        }
        .custom-scrollbar::-webkit-scrollbar-track {
          background: transparent;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb {
          background: #374151;
          border-radius: 10px;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover {
          background: #4b5563;
        }
      `}</style>
    </div>
  );
}