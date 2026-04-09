'use client';

import { useState, useEffect, useCallback } from 'react';
import { useHazardKpis } from '@/hooks/useHazards';
import type { Hazard } from '@/hooks/useHazards';

interface RiskResult {
  riskScore: number;
  safetyScore: number;
  suggestion: string;
  suggestionType: string;
  color: string;
  hazardCount: number;
  breakdown: {
    critical: number;
    warnings: number;
    inspections: number;
    weighStations: number;
    timePenalty: number;
  };
  hazards: Hazard[];
}

interface Props {
  originLat?: number;
  originLng?: number;
  destLat?: number;
  destLng?: number;
  durationMinutes?: number;
  autoFetch?: boolean;
  liveHazards?: Hazard[]; // from FleetHazardKpiCards
  onRerouteRequest?: () => void;
}

export default function RoadDoggRiskPanel({
  originLat, originLng,
  destLat, destLng,
  durationMinutes = 0,
  autoFetch = false,
  liveHazards = [],
  onRerouteRequest,
}: Props) {
  const [result, setResult] = useState<RiskResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // KPI adjustment from live hazards
  const kpis = useHazardKpis(liveHazards);
  const kpiAdjustment = (kpis.critical * 10) + (kpis.inspections * 5);

  const adjustedRiskScore = result
    ? Math.min(100, result.riskScore + kpiAdjustment)
    : null;
  const adjustedSafetyScore = adjustedRiskScore !== null
    ? 100 - adjustedRiskScore
    : null;

  const fetchRisk = useCallback(async () => {
    if (!originLat || !originLng || !destLat || !destLng) return;

    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/roaddogg/route-score', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          originLat, originLng,
          destLat, destLng,
          durationMinutes,
        }),
      });
      if (!res.ok) throw new Error('Failed to score route');
      setResult(await res.json());
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [originLat, originLng, destLat, destLng, durationMinutes]);

  useEffect(() => {
    if (autoFetch) fetchRisk();
  }, [autoFetch, fetchRisk]);

  const displayRisk = adjustedRiskScore ?? result?.riskScore ?? 0;
  const displaySafety = adjustedSafetyScore ?? result?.safetyScore ?? 100;

  const getColor = (risk: number) => {
    if (risk <= 20) return '#22c55e';
    if (risk <= 40) return '#eab308';
    if (risk <= 65) return '#f97316';
    return '#ef4444';
  };

  const getLabel = (risk: number) => {
    if (risk <= 20) return 'LOW RISK';
    if (risk <= 40) return 'MODERATE';
    if (risk <= 65) return 'HIGH RISK';
    return 'CRITICAL';
  };

  const color = getColor(displayRisk);
  const isHighRisk = displayRisk > 65;
  const isCritical = displayRisk > 80;

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center gap-2 mb-4">
        <span className="text-xl">🤖</span>
        <h3 className="text-white font-bold">RoadDogg AI</h3>
        {kpiAdjustment > 0 && (
          <span className="text-xs bg-orange-900/50 text-orange-400 px-2 py-0.5 rounded-full">
            +{kpiAdjustment} live adj.
          </span>
        )}
      </div>

      {!result && !loading && (
        <div className="text-center py-4">
          <p className="text-gray-400 text-sm mb-3">
            Scan route corridor for hazards
          </p>
          <button
            onClick={fetchRisk}
            disabled={!originLat || !destLat}
            className="bg-blue-600 hover:bg-blue-700 disabled:opacity-40 text-white text-sm px-4 py-2 rounded-lg transition"
          >
            Analyze Route Risk
          </button>
        </div>
      )}

      {loading && (
        <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
          <div className="w-4 h-4 border-2 border-blue-400 border-t-transparent rounded-full animate-spin" />
          Scanning 3 checkpoints along route...
        </div>
      )}

      {error && <p className="text-red-400 text-sm">{error}</p>}

      {result && !loading && (
        <div className="space-y-4">
          {/* Urgency alert */}
          {isCritical && (
            <div className="bg-red-900/40 border border-red-600 rounded-lg px-3 py-2">
              <p className="text-red-400 text-xs font-bold">
                ⚠️ CRITICAL RISK — RECOMMENDED REROUTE
              </p>
            </div>
          )}
          {isHighRisk && !isCritical && (
            <div className="bg-orange-900/40 border border-orange-600 rounded-lg px-3 py-2">
              <p className="text-orange-400 text-xs font-bold">
                ⚠️ HIGH RISK — PROCEED WITH CAUTION
              </p>
            </div>
          )}

          {/* Dual score display */}
          <div className="grid grid-cols-2 gap-3">
            <div className="text-center">
              <div
                className="w-14 h-14 rounded-full border-4 flex items-center justify-center mx-auto mb-1"
                style={{ borderColor: color }}
              >
                <span className="text-white font-bold">{displayRisk}</span>
              </div>
              <p className="text-xs font-bold" style={{ color }}>
                {getLabel(displayRisk)}
              </p>
              <p className="text-gray-500 text-xs">Risk Score</p>
            </div>
            <div className="text-center">
              <div className="w-14 h-14 rounded-full border-4 border-green-500 flex items-center justify-center mx-auto mb-1">
                <span className="text-white font-bold">{displaySafety}</span>
              </div>
              <p className="text-xs font-bold text-green-400">SAFETY</p>
              <p className="text-gray-500 text-xs">Safety Score</p>
            </div>
          </div>

          {/* Risk bar */}
          <div>
            <div className="flex justify-between text-xs text-gray-500 mb-1">
              <span>Safe</span>
              <span>Dangerous</span>
            </div>
            <div className="bg-gray-800 rounded-full h-3 overflow-hidden">
              <div
                className="h-3 rounded-full transition-all duration-700"
                style={{ width: `${displayRisk}%`, backgroundColor: color }}
              />
            </div>
          </div>

          {/* AI suggestion */}
          <p className="text-gray-300 text-sm">{result.suggestion}</p>

          {/* Breakdown grid */}
          <div className="grid grid-cols-2 gap-2 text-xs">
            {[
              { label: 'Critical', val: result.breakdown.critical, color: 'text-red-400' },
              { label: 'Warnings', val: result.breakdown.warnings, color: 'text-orange-400' },
              { label: 'Inspections', val: result.breakdown.inspections, color: 'text-blue-400' },
              { label: 'Time penalty', val: result.breakdown.timePenalty, color: 'text-purple-400' },
            ].map(item => (
              <div key={item.label} className="bg-gray-800 rounded-lg p-2">
                <p className={`font-bold ${item.color}`}>{item.val}</p>
                <p className="text-gray-400">{item.label}</p>
              </div>
            ))}
          </div>

          {/* Reroute action */}
          {isHighRisk && (
            <button
              onClick={onRerouteRequest}
              className="w-full bg-red-600 hover:bg-red-700 text-white text-sm px-3 py-2 rounded-lg transition font-medium"
            >
              🔄 Reroute Now
            </button>
          )}

          <button
            onClick={fetchRisk}
            className="w-full text-xs text-gray-500 hover:text-gray-300 transition"
          >
            ↻ Refresh analysis
          </button>
        </div>
      )}
    </div>
  );
}
