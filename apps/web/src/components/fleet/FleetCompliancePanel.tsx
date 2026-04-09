'use client';

import { useEffect, useState } from 'react';

interface Driver {
  id: string;
  name: string;
  hos_driving_minutes: number;
  status: string;
  truck_number?: string;
}

export default function FleetCompliancePanel({ orgId }: { orgId: string }) {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`/api/drivers/list?orgId=${orgId}`)
      .then(r => r.json())
      .then(d => {
        setDrivers(d.drivers || []);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [orgId]);

  const critical = drivers.filter(d => d.hos_driving_minutes >= 600);
  const atRisk = drivers.filter(d =>
    d.hos_driving_minutes >= 540 && d.hos_driving_minutes < 600
  );
  const safe = drivers.filter(d => d.hos_driving_minutes < 540);

  const formatHos = (minutes: number) => {
    const remaining = Math.max(0, 660 - minutes);
    const h = Math.floor(remaining / 60);
    const m = remaining % 60;
    return `${h}h ${m}m left`;
  };

  if (loading) {
    return (
      <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
        <div className="animate-pulse h-24 bg-gray-800 rounded-xl" />
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-bold text-white">🛡️ HOS Compliance</h2>
        <span className="text-xs text-gray-400">{drivers.length} drivers</span>
      </div>

      {drivers.length === 0 ? (
        <p className="text-gray-500 text-sm">No drivers in your fleet yet</p>
      ) : (
        <div className="space-y-3">
          {/* Summary badges */}
          <div className="grid grid-cols-3 gap-2 text-center text-xs">
            <div className="rounded-lg bg-red-900/30 border border-red-700/50 p-2">
              <p className="text-red-400 font-bold text-lg">{critical.length}</p>
              <p className="text-red-300">Critical</p>
            </div>
            <div className="rounded-lg bg-yellow-900/30 border border-yellow-700/50 p-2">
              <p className="text-yellow-400 font-bold text-lg">{atRisk.length}</p>
              <p className="text-yellow-300">At Risk</p>
            </div>
            <div className="rounded-lg bg-green-900/30 border border-green-700/50 p-2">
              <p className="text-green-400 font-bold text-lg">{safe.length}</p>
              <p className="text-green-300">Safe</p>
            </div>
          </div>

          {/* Critical drivers */}
          {critical.length > 0 && (
            <div>
              <p className="text-xs text-red-400 font-medium mb-1">
                🚨 Over limit — must rest
              </p>
              {critical.map(d => (
                <div key={d.id} className="flex justify-between items-center bg-red-900/20 border border-red-700/30 rounded-lg px-3 py-2 mb-1">
                  <span className="text-white text-sm">{d.name}</span>
                  <span className="text-red-400 text-xs font-bold">
                    {formatHos(d.hos_driving_minutes)}
                  </span>
                </div>
              ))}
            </div>
          )}

          {/* At risk drivers */}
          {atRisk.length > 0 && (
            <div>
              <p className="text-xs text-yellow-400 font-medium mb-1">
                ⚠️ Nearing limit
              </p>
              {atRisk.map(d => (
                <div key={d.id} className="flex justify-between items-center bg-yellow-900/20 border border-yellow-700/30 rounded-lg px-3 py-2 mb-1">
                  <span className="text-white text-sm">{d.name}</span>
                  <span className="text-yellow-400 text-xs font-bold">
                    {formatHos(d.hos_driving_minutes)}
                  </span>
                </div>
              ))}
            </div>
          )}

          {/* Safe drivers */}
          {safe.length > 0 && (
            <div>
              <p className="text-xs text-green-400 font-medium mb-1">
                ✅ Within limits
              </p>
              {safe.slice(0, 3).map(d => (
                <div key={d.id} className="flex justify-between items-center bg-gray-800 rounded-lg px-3 py-2 mb-1">
                  <span className="text-white text-sm">{d.name}</span>
                  <span className="text-green-400 text-xs">
                    {formatHos(d.hos_driving_minutes)}
                  </span>
                </div>
              ))}
              {safe.length > 3 && (
                <p className="text-gray-500 text-xs text-center">
                  +{safe.length - 3} more drivers
                </p>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
