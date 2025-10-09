"use client";
import React, { useState } from "react";
import { useHazards, useHazardKpis } from "@/hooks/useHazards";
import HazardMap from "@/components/HazardMap";
import AlertFeed from "@/components/AlertFeed";
import KpiBar from "@/components/KpiBar";
import type { BBox } from "@/lib/geo";

export default function FleetHazardsPage() {
  const [bbox, setBbox] = useState<BBox | undefined>(undefined);
  const fleetId = undefined; // TODO: plug in from session claims if needed

  const { hazards, loading } = useHazards({ fleetId, bbox });
  const kpis = useHazardKpis();

  const onSelect = () => {}; // open right panel, etc.

  return (
    <div className="p-4 grid gap-4">
      <KpiBar k={kpis} />
      <div className="grid md:grid-cols-2 gap-4">
        <HazardMap hazards={hazards} onSelect={onSelect} onBoundsChange={setBbox} />
        <div className="max-h-[480px] overflow-auto">
          <AlertFeed hazards={hazards} />
        </div>
      </div>
      {loading && <div className="text-sm opacity-60">Loading realtime hazards…</div>}
    </div>
  );
}
