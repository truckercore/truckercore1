"use client";
import React, { useMemo, useState } from "react";
import { Hazard, SEVERITY_COLOR } from "@/lib/geo";
import { ChevronDown, ChevronUp, Lightbulb } from "lucide-react";

type CoachingTip = { id: string; hazard_id: string; tip: string; status: string; created_at: string };

type Props = {
  hazards: Hazard[];
  coachingTips?: CoachingTip[]; // optional prefetch; can also fetch on demand
};

function severityRank(s: Hazard["severity"]) {
  return ({ critical: 0, high: 1, medium: 2, low: 3 } as any)[s] ?? 3;
}

function groupKey(h: Hazard) {
  // group by type + rounded vicinity to reduce duplicates in feed
  const lat = Math.round(h.lat * 10) / 10;
  const lng = Math.round(h.lng * 10) / 10;
  return `${h.type}|${lat},${lng}`;
}

export default function AlertFeed({ hazards, coachingTips = [] }: Props) {
  const [openId, setOpenId] = useState<string | null>(null);

  const items = useMemo(() => {
    // Sort by severity then detected_at desc
    return [...hazards].sort((a, b) => {
      const sr = severityRank(a.severity) - severityRank(b.severity);
      return sr !== 0 ? sr : new Date(b.detected_at).getTime() - new Date(a.detected_at).getTime();
    });
  }, [hazards]);

  // Group contiguous/nearby hazards of same type for a cleaner feed
  const groups = useMemo(() => {
    const map = new Map<string, Hazard[]>();
    items.forEach((h) => {
      const k = groupKey(h);
      const arr = map.get(k) ?? [];
      arr.push(h);
      map.set(k, arr);
    });
    // derive a representative row per group (highest severity, newest)
    const reps = Array.from(map.values()).map((arr) => {
      const rep = [...arr].sort((a, b) => {
        const sr = severityRank(a.severity) - severityRank(b.severity);
        return sr !== 0 ? sr : new Date(b.detected_at).getTime() - new Date(a.detected_at).getTime();
      })[0];
      return { rep, all: arr };
    });
    // priority sort reps again to ensure global order
    return reps.sort((a, b) => {
      const sr = severityRank(a.rep.severity) - severityRank(b.rep.severity);
      return sr !== 0 ? sr : new Date(b.rep.detected_at).getTime() - new Date(a.rep.detected_at).getTime();
    });
  }, [items]);

  const tipByHazard = useMemo(() => {
    const map = new Map<string, CoachingTip>();
    coachingTips.forEach((t) => map.set(t.hazard_id, t));
    return map;
  }, [coachingTips]);

  async function acknowledge(hazardId: string) {
    try {
      await fetch("/api/hazards/ack", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ hazard_id: hazardId }),
      });
    } catch {
      // ignore
    }
  }

  return (
    <div className="divide-y rounded-2xl border border-black/10 bg-white overflow-hidden">
      {groups.map(({ rep, all }) => {
        const color = SEVERITY_COLOR[rep.severity];
        const isOpen = openId === rep.id;
        const tip = tipByHazard.get(rep.id) ?? tipByHazard.get(all[0]?.id ?? "");
        const countExtra = Math.max(0, all.length - 1);
        return (
          <div key={rep.id} className="p-3">
            <div className="flex items-start gap-3">
              <div className="mt-1 h-3 w-3 rounded-full" style={{ background: color }} />
              <div className="flex-1">
                <div className="flex items-center justify-between">
                  <div className="font-medium">
                    {rep.title ?? rep.type}
                    <span className="text-xs opacity-60">
                      {" "}· {new Date(rep.detected_at).toLocaleTimeString()}
                      {countExtra > 0 ? ` · +${countExtra} nearby` : ""}
                    </span>
                  </div>
                  <button
                    className="text-sm px-2 py-1 rounded hover:bg-black/5"
                    onClick={() => setOpenId(isOpen ? null : rep.id)}
                    aria-expanded={isOpen}
                    aria-controls={`alert-panel-${rep.id}`}
                  >
                    {isOpen ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                  </button>
                </div>
                <div className="text-sm opacity-80">{rep.description}</div>

                {isOpen && (
                  <div id={`alert-panel-${rep.id}`} className="mt-2 grid gap-2">
                    <div className="text-xs">
                      <span className="opacity-70">Location: </span>
                      {rep.lat.toFixed(4)}, {rep.lng.toFixed(4)}
                    </div>

                    {all.length > 1 && (
                      <div className="text-xs opacity-70">
                        Similar in vicinity:
                        <ul className="list-disc ml-5 mt-1">
                          {all.slice(0, 5).map((h) => (
                            <li key={h.id}>
                              {h.type} · {new Date(h.detected_at).toLocaleTimeString()}
                            </li>
                          ))}
                          {all.length > 5 && <li>… {all.length - 5} more</li>}
                        </ul>
                      </div>
                    )}

                    {tip && (
                      <div className={"text-xs p-2 rounded flex gap-2 items-start bg-amber-50 border border-amber-200"}>
                        <Lightbulb className="w-4 h-4 text-amber-600 mt-0.5" />
                        <div>
                          <div className="font-semibold mb-0.5">Coaching Tip</div>
                          <div>{tip.tip}</div>
                          <div className="mt-1 opacity-60">Status: {tip.status}</div>
                        </div>
                      </div>
                    )}

                    <div className="flex gap-2">
                      <button
                        className="text-xs px-2 py-1 rounded bg-neutral-100 hover:bg-neutral-200"
                        onClick={() => acknowledge(rep.id)}
                      >
                        Acknowledge
                      </button>
                      <button
                        className="text-xs px-2 py-1 rounded bg-neutral-100 hover:bg-neutral-200"
                        onClick={() => {
                          const url = `https://www.google.com/maps/dir/?api=1&destination=${rep.lat},${rep.lng}`;
                          try { window.open(url, "_blank"); } catch {}
                        }}
                      >
                        Navigate
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        );
      })}
      {groups.length === 0 && <div className="p-4 text-sm text-center opacity-60">No active hazards.</div>}
    </div>
  );
}
