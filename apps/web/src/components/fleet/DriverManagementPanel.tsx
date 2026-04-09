'use client';

import { useEffect, useState } from 'react';

interface Driver {
  id: string;
  name: string;
  truck_number?: string;
  status: string;
  hos_driving_minutes: number;
}

export default function DriverManagementPanel({ orgId }: { orgId: string }) {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [name, setName] = useState('');
  const [truck, setTruck] = useState('');
  const [phone, setPhone] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const loadDrivers = () => {
    fetch(`/api/drivers/list?orgId=${orgId}`)
      .then(r => r.json())
      .then(d => setDrivers(d.drivers || []))
      .catch(() => {});
  };

  useEffect(() => { loadDrivers(); }, [orgId]);

  const createDriver = async () => {
    if (!name.trim()) return;
    setLoading(true);
    setMessage('');
    try {
      const res = await fetch('/api/drivers/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, truckNumber: truck, phone, orgId }),
      });
      const data = await res.json();
      if (res.ok) {
        setName('');
        setTruck('');
        setPhone('');
        setMessage('✓ Driver added');
        loadDrivers();
      } else {
        const errorMsg = data.error || 'Failed to add driver';
        setMessage(errorMsg);
        alert(errorMsg);
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Error adding driver';
      setMessage(errorMsg);
      alert(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const formatHos = (minutes: number) => {
    const remaining = Math.max(0, 660 - minutes);
    const h = Math.floor(remaining / 60);
    const m = remaining % 60;
    return `${h}h ${m}m`;
  };

  const getHosColor = (minutes: number) => {
    const remaining = 660 - minutes;
    if (remaining <= 60) return 'text-red-400';
    if (remaining <= 180) return 'text-yellow-400';
    return 'text-green-400';
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'driving': return 'bg-blue-900/50 text-blue-300';
      case 'available': return 'bg-green-900/50 text-green-300';
      case 'off_duty': return 'bg-gray-800 text-gray-400';
      default: return 'bg-gray-800 text-gray-400';
    }
  };

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-bold text-white">👤 Driver Management</h2>
        <span className="text-xs text-gray-400">{drivers.length} drivers</span>
      </div>

      {/* Add driver form */}
      <div className="bg-gray-800 rounded-xl p-3 mb-4 space-y-2">
        <p className="text-xs text-gray-400 font-medium uppercase tracking-wide">Add Driver</p>
        <input
          placeholder="Full name *"
          value={name}
          onChange={e => setName(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && createDriver()}
          className="w-full bg-gray-700 border border-gray-600 text-white text-sm px-3 py-2 rounded-lg focus:border-blue-500 outline-none"
        />
        <div className="grid grid-cols-2 gap-2">
          <input
            placeholder="Truck # (optional)"
            value={truck}
            onChange={e => setTruck(e.target.value)}
            className="bg-gray-700 border border-gray-600 text-white text-sm px-3 py-2 rounded-lg focus:border-blue-500 outline-none"
          />
          <input
            placeholder="Phone (optional)"
            value={phone}
            onChange={e => setPhone(e.target.value)}
            className="bg-gray-700 border border-gray-600 text-white text-sm px-3 py-2 rounded-lg focus:border-blue-500 outline-none"
          />
        </div>
        <button
          onClick={createDriver}
          disabled={loading || !name.trim()}
          className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-40 text-white text-sm py-2 rounded-lg transition font-medium"
        >
          {loading ? 'Adding...' : '+ Add Driver'}
        </button>
        {message && (
          <p className={`text-xs ${message.startsWith('✓') ? 'text-green-400' : 'text-red-400'}`}>
            {message}
          </p>
        )}
      </div>

      {/* Driver list */}
      <div className="space-y-2">
        {drivers.length === 0 ? (
          <div className="text-center py-6">
            <p className="text-3xl mb-2">🚛</p>
            <p className="text-gray-400 text-sm">No drivers yet</p>
            <p className="text-gray-600 text-xs">Add your first driver above</p>
          </div>
        ) : (
          drivers.map(d => (
            <div key={d.id} className="bg-gray-800 rounded-xl px-3 py-3 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-gray-700 flex items-center justify-center text-white font-bold text-sm">
                  {d.name.charAt(0).toUpperCase()}
                </div>
                <div>
                  <p className="text-white text-sm font-medium">{d.name}</p>
                  <p className="text-gray-400 text-xs">
                    {d.truck_number || 'No truck assigned'}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className={`text-xs px-2 py-0.5 rounded-full ${getStatusColor(d.status)}`}>
                  {d.status || 'available'}
                </span>
                <span className={`text-xs font-bold ${getHosColor(d.hos_driving_minutes)}`}>
                  {formatHos(d.hos_driving_minutes)}
                </span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
