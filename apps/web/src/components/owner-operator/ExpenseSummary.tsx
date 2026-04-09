'use client';

import { useEffect, useState } from 'react';

interface Summary {
  totalTrips: number;
  totalMiles: number;
  totalFuelCost: number;
  totalTollCost: number;
  totalExpenses: number;
}

export default function ExpenseSummary() {
  const [data, setData] = useState<{ summary: Summary; trips: any[] } | null>(null);
  const [period, setPeriod] = useState(30);

  useEffect(() => {
    fetch(`/api/trips/history?days=${period}`)
      .then(r => r.json())
      .then(setData)
      .catch(() => {});
  }, [period]);

  const summary = data?.summary;

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-5 text-white">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-bold text-lg">📊 Expense Summary</h3>
        <select
          value={period}
          onChange={e => setPeriod(Number(e.target.value))}
          className="bg-gray-800 text-white text-xs rounded-lg px-2 py-1 border border-gray-700"
        >
          <option value={7}>Last 7 days</option>
          <option value={30}>Last 30 days</option>
          <option value={90}>Last 90 days</option>
          <option value={365}>This year</option>
        </select>
      </div>

      {!summary ? (
        <div className="animate-pulse space-y-2">
          {[1,2,3].map(i => <div key={i} className="h-12 bg-gray-800 rounded-lg" />)}
        </div>
      ) : (
        <div className="space-y-3">
          {/* Key metrics */}
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-gray-800 rounded-xl p-3">
              <p className="text-gray-400 text-xs">Total Miles</p>
              <p className="text-white font-bold text-xl">{summary.totalMiles}</p>
              <p className="text-gray-500 text-xs">{summary.totalTrips} trips</p>
            </div>
            <div className="bg-gray-800 rounded-xl p-3">
              <p className="text-gray-400 text-xs">Total Expenses</p>
              <p className="text-red-400 font-bold text-xl">${summary.totalExpenses}</p>
              <p className="text-gray-500 text-xs">auto-logged</p>
            </div>
          </div>

          {/* Expense breakdown */}
          <div className="bg-gray-800 rounded-xl p-3 space-y-2">
            <p className="text-gray-400 text-xs font-medium uppercase tracking-wide">Breakdown</p>
            <div className="flex justify-between items-center">
              <span className="text-sm">⛽ Fuel</span>
              <span className="text-red-400 font-medium">${summary.totalFuelCost}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm">🛣️ Tolls</span>
              <span className="text-yellow-400 font-medium">${summary.totalTollCost}</span>
            </div>
          </div>

          {/* Tax savings estimate */}
          <div className="bg-blue-900/30 border border-blue-700/50 rounded-xl p-3">
            <p className="text-blue-400 text-xs font-medium">💡 Estimated Tax Deduction</p>
            <p className="text-white font-bold text-lg">
              ${Math.round(summary.totalExpenses * 0.22)}
            </p>
            <p className="text-gray-400 text-xs">
              Based on ~22% self-employment tax rate
            </p>
          </div>

          {/* Recent trips */}
          {data?.trips?.length > 0 && (
            <div>
              <p className="text-gray-400 text-xs font-medium uppercase tracking-wide mb-2">
                Recent Trips
              </p>
              <div className="space-y-2 max-h-48 overflow-y-auto">
                {data.trips.slice(0, 5).map(trip => (
                  <div key={trip.id} className="flex justify-between items-center text-sm bg-gray-800 rounded-lg px-3 py-2">
                    <div>
                      <p className="text-white">{trip.total_miles} mi</p>
                      <p className="text-gray-500 text-xs">
                        {new Date(trip.start_time).toLocaleDateString()}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="text-red-400">${((trip.fuel_cost || 0) + (trip.total_toll_cost || 0)).toFixed(2)}</p>
                      <p className="text-gray-500 text-xs">fuel + tolls</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
