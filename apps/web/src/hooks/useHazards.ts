// Stub hook - to be implemented
import { useState } from "react";
import type { BBox } from "@/lib/geo";

interface UseHazardsOptions {
  fleetId?: string;
  bbox?: BBox;
}

export function useHazards({ fleetId, bbox }: UseHazardsOptions) {
  const [hazards] = useState([]);
  const [loading] = useState(false);
  
  return { hazards, loading };
}

export function useHazardKpis() {
  return {
    totalHazards: 0,
    criticalHazards: 0,
    activeAlerts: 0,
  };
}
