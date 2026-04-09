'use client';

import { useEffect, useState } from 'react';

export default function IFTAReport() {
  const [data, setData] = useState<any>(null);
  const year = new Date().getFullYear();

  useEffect(() => {
    fetch(`/api/ifta/report?year=${year}`)
      .then(r => r.json())
      .then(setData)
      .catch(() => {});
  }, [year]);

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-5 text-white">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="font-bold text-lg">📋 IFTA Report</h3>
          <p className="text-gray-400 text-xs">Mileage by state — {year}</p>
        </div>
        {data?.reportReady && (
          <span className="bg-green-900/50 text-green-400 text-xs px-2 py-1 rounded-full">
            Ready
          </span>
        )}
      </div>

      {!data ? (
        <div className="animate-pulse h-32 bg-gray-800 rounded-xl" />
      ) : !data.reportReady ? (
        <div className="text-center py-6">
          <p className="text-4xl mb-2">🗺️</p>
          <p className="text-gray-400 text-sm">No trips logged yet</p>
          <p className="text-gray-600 text-xs mt-1">
            Start tracking trips to generate IFTA reports
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          <div className="bg-gray-800 rounded-xl p-3 flex justify-between">
            <span className="text-gray-400 text-sm">Total Miles</span>
            <span className="font-bold">{data.totalMiles} mi</span>
          </div>

          <div className="space-y-2">
            <p className="text-gray-400 text-xs uppercase tracking-wide">By State</p>
            {data.stateBreakdown.map((s: any) => (
              <div key={s.state} className="flex items-center gap-3">
                <span className="text-white font-bold w-8">{s.state}</span>
                <div className="flex-1 bg-gray-800 rounded-full h-2">
                  <div
                    className="bg-blue-500 h-2 rounded-full"
                    style={{ width: `${Math.min(100, (s.miles / data.totalMiles) * 100)}%` }}
                  />
                </div>
                <span className="text-gray-300 text-sm w-16 text-right">{s.miles} mi</span>
              </div>
            ))}
          </div>

          <div className="bg-blue-900/30 border border-blue-700/50 rounded-xl p-3">
            <p className="text-blue-400 text-xs">
              💡 Share this report with your accountant or tax software
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
