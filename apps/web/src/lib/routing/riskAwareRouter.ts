// TypeScript
import type { TruckProfile } from "./types";

export type Hazard = { lat: number; lng: number; radius_m: number; type: string; severity: number };
export type RouteReq = {
  origin: [number, number];
  destination: [number, number];
  waypoints?: [number, number][];
  truck: TruckProfile;
};

export async function planRoute(req: RouteReq, hazards: Hazard[]) {
  const base = await truckDirectionsAPI(req);

  const intersects = hazards.some((h) => polylineWithinRadius(base.polyline, [h.lat, h.lng], h.radius_m));
  if (!intersects) return base;

  const alt = await truckDirectionsAPI({
    ...req,
    waypoints: [...(req.waypoints ?? []), ...computeBypassPoints(base, hazards)],
  });

  return alt.cost < base.cost + 300 ? alt : base;
}

// TODO: replace with real HERE/Mapbox truck routing
async function truckDirectionsAPI(_req: RouteReq): Promise<{ polyline: [number, number][]; cost: number }> {
  return { polyline: [], cost: 0 };
}

function polylineWithinRadius(_poly: [number, number][], _center: [number, number], _m: number) {
  return true;
}
function computeBypassPoints(_route: any, _hazards: Hazard[]) {
  return [] as [number, number][];
}
