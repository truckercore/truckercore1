'use client';

import { useState } from 'react';
import LiveTrackingMap from '@/components/gps/LiveTrackingMap';

export default function GPSPage() {
  const [selectedTruck, setSelectedTruck] = useState<any>(null);

  // Sample data to verify the component
  const trucks = [
    {
      vehicle_id: 'TRK-101',
      driver_name: 'John Doe',
      latitude: 40.7128,
      longitude: -74.0060,
      speed_mph: 65,
      heading: 90,
      status: 'en_route',
      route_geometry: {
        coordinates: [
          [-74.0060, 40.7128],
          [-73.9352, 40.7306],
        ]
      }
    },
    {
      vehicle_id: 'TRK-202',
      driver_name: 'Jane Smith',
      latitude: 34.0522,
      longitude: -118.2437,
      speed_mph: 0,
      heading: 0,
      status: 'idle',
    }
  ];

  return (
    <div className="flex flex-col h-screen bg-gray-950 text-white">
      <header className="p-4 border-b border-gray-800 flex justify-between items-center">
        <h1 className="text-xl font-bold">Fleet Dispatch Board</h1>
        <div className="text-sm text-gray-400">Live GPS Tracking</div>
      </header>
      
      <main className="flex-1 flex overflow-hidden">
        <div className="w-1/4 border-r border-gray-800 overflow-y-auto p-4">
          <h2 className="text-lg font-semibold mb-4">Trucks</h2>
          <div className="space-y-2">
            {trucks.map(truck => (
              <div 
                key={truck.vehicle_id}
                onClick={() => setSelectedTruck(truck)}
                className={`p-3 rounded-lg cursor-pointer border ${
                  selectedTruck?.vehicle_id === truck.vehicle_id 
                    ? 'bg-blue-900/30 border-blue-500' 
                    : 'bg-gray-900 border-gray-800 hover:border-gray-700'
                }`}
              >
                <div className="font-bold">{truck.vehicle_id}</div>
                <div className="text-sm text-gray-400">{truck.driver_name}</div>
                <div className="mt-1 flex justify-between items-center">
                  <span className={`text-xs px-2 py-0.5 rounded-full ${
                    truck.status === 'en_route' ? 'bg-blue-600/20 text-blue-400' : 'bg-gray-700 text-gray-300'
                  }`}>
                    {truck.status}
                  </span>
                  <span className="text-xs text-gray-500">{truck.speed_mph} mph</span>
                </div>
              </div>
            ))}
          </div>
        </div>
        
        <div className="flex-1 relative">
          <LiveTrackingMap 
            trucks={trucks} 
            selected={selectedTruck} 
            onSelectTruck={setSelectedTruck} 
          />
        </div>
      </main>
    </div>
  );
}
