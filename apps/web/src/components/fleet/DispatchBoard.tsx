'use client';

import { useEffect, useState } from 'react';

interface Driver {
  id: string;
  name: string;
  truck_number: string;
  status: string;
  hos_driving_minutes: number;
}

interface Load {
  id: string;
  pickup_address: string;
  drop_address: string;
  price: number;
  miles: number;
  status: string;
  assigned_driver_id?: string;
}

export default function DispatchBoard({ orgId }: { orgId: string }) {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loads, setLoads] = useState<Load[]>([]);
  const [assigning, setAssigning] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    // Load drivers
    fetch(`/api/drivers/list?orgId=${orgId}`)
      .then(r => r.json())
      .then(d => setDrivers(d.drivers || []))
      .catch(() => {});

    // Load open loads
    fetch('/api/loads')
      .then(r => r.json())
      .then(d => setLoads(d.loads || []))
      .catch(() => {});
  }, [orgId]);

  const assignLoad = async (loadId: string, driverId: string) => {
    setAssigning(true);
    setMessage('');
    try {
      const res = await fetch('/api/dispatch/assign', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loadId, driverId }),
      });
      const data = await res.json();

      if (!res.ok) {
        setMessage(data.error || 'Failed to assign');
      } else {
        setMessage(`✓ Load assigned to ${data.driver}`);
        setLoads(prev => prev.map(l =>
          l.id === loadId ? { ...l, status: 'assigned', assigned_driver_id: driverId } : l
        ));
      }
    } catch {
      setMessage('Assignment failed');
    } finally {
      setAssigning(false);
    }
  };

  const getHosColor = (minutes: number) => {
    const remaining = 660 - minutes;
    if (remaining <= 60) return 'text-red-400';
    if (remaining <= 180) return 'text-yellow-400';
    return 'text-green-400';
  };

  const formatHos = (minutes: number) => {
    const remaining = 660 - minutes;
    const h = Math.floor(remaining / 60);
    const m = remaining % 60;
    return `${h}h ${m}m left`;
  };

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-bold text-white">🚛 Dispatch Board</h2>

      {message && (
        <div className={`rounded-lg px-4 py-2 text-sm ${
          message.startsWith('✓') ? 'bg-green-900/50 text-green-400' : 'bg-red-900/50 text-red-400'
        }`}>
          {message}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Drivers */}
        <div>
          <h3 className="text-gray-400 text-sm font-medium uppercase mb-3">
            Drivers ({drivers.length})
          </h3>
          <div className="space-y-2">
            {drivers.map(driver => (
              <div key={driver.id} className="bg-gray-800 rounded-xl p-3 flex items-center justify-between">
                <div>
                  <p className="text-white font-medium">{driver.name}</p>
                  <p className="text-gray-400 text-xs">
                    {driver.truck_number || 'No truck'} · {driver.status}
                  </p>
                </div>
                <div className="text-right">
                  <p className={`text-sm font-bold ${getHosColor(driver.hos_driving_minutes)}`}>
                    {formatHos(driver.hos_driving_minutes)}
                  </p>
                  <p className="text-gray-500 text-xs">HOS</p>
                </div>
              </div>
            ))}
            {drivers.length === 0 && (
              <p className="text-gray-500 text-sm">No drivers yet</p>
            )}
          </div>
        </div>

        {/* Open Loads */}
        <div>
          <h3 className="text-gray-400 text-sm font-medium uppercase mb-3">
            Open Loads ({loads.filter(l => l.status === 'open').length})
          </h3>
          <div className="space-y-2">
            {loads.filter(l => l.status === 'open').map(load => (
              <div key={load.id} className="bg-gray-800 rounded-xl p-3">
                <div className="flex justify-between mb-2">
                  <div>
                    <p className="text-white text-sm font-medium">{load.pickup_address}</p>
                    <p className="text-blue-400 text-xs">→ {load.drop_address}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-green-400 font-bold">${load.price}</p>
                    <p className="text-gray-400 text-xs">{load.miles} mi</p>
                  </div>
                </div>
                {drivers.length > 0 && (
                  <select
                    onChange={e => e.target.value && assignLoad(load.id, e.target.value)}
                    disabled={assigning}
                    className="w-full bg-gray-700 text-white text-xs rounded-lg px-2 py-1 border border-gray-600"
                    defaultValue=""
                  >
                    <option value="">Assign driver...</option>
                    {drivers
                      .filter(d => d.status === 'available' && (660 - d.hos_driving_minutes) > 60)
                      .map(d => (
                        <option key={d.id} value={d.id}>{d.name}</option>
                      ))
                    }
                  </select>
                )}
              </div>
            ))}
            {loads.filter(l => l.status === 'open').length === 0 && (
              <p className="text-gray-500 text-sm">No open loads</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
