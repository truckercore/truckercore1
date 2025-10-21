// TypeScript
export type TruckProfile = {
  height_ft?: number;
  hazmat?: boolean;
  weight_kg?: number;
};

export type Hazard = {
  id: string;
  type: string;
  severity: number;
  lat: number;
  lng: number;
  radius_m: number;
};

export type RouteLeg = { lat: number; lng: number };

export function avoidHazards(route: RouteLeg[], hazards: Hazard[], bufferM = 150): RouteLeg[] {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const distM = (a: RouteLeg, b: RouteLeg) => {
    const R = 6371000;
    const dLat = toRad(b.lat - a.lat);
    const dLon = toRad(b.lng - a.lng);
    const la1 = toRad(a.lat);
    const la2 = toRad(b.lat);
    const s = Math.sin(dLat / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin(dLon / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(s));
  };
  const keep: RouteLeg[] = [];
  for (const p of route) {
    const inside = hazards.some((h) => distM(p, { lat: h.lat, lng: h.lng }) <= (h.radius_m + bufferM));
    if (!inside) keep.push(p);
  }
  return keep.length ? keep : route;
}

export function applyTruckConstraints(route: RouteLeg[], _truck: TruckProfile) {
  // Placeholder: integrate low bridges / hazmat bans via geofences.
  return route;
}
