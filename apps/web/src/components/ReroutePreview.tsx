// TypeScript
import React from "react";
import { avoidHazards, applyTruckConstraints, Hazard, RouteLeg, TruckProfile } from "@/lib/reroute/rerouteEngine";

export function ReroutePreview({
  route,
  hazards,
  truck,
}: {
  route: RouteLeg[];
  hazards: Hazard[];
  truck: TruckProfile;
}) {
  const filtered = applyTruckConstraints(avoidHazards(route, hazards), truck);
  return (
    <div className="card">
      <div className="card-header">Auto-reroute Preview</div>
      <div className="card-body">
        <div>Original points: {route.length}</div>
        <div>Filtered points: {filtered.length}</div>
      </div>
    </div>
  );
}
