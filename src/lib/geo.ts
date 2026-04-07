// TypeScript
export type BBox = [number, number, number, number]; // [minLng, minLat, maxLng, maxLat]

export function inBBox(lat: number, lng: number, bbox: BBox): boolean {
  const [minLng, minLat, maxLng, maxLat] = bbox;
  return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
}

export function haversineDistanceMeters(a: [number, number], b: [number, number]): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 6371000;
  const dLat = toRad(b[0] - a[0]);
  const dLng = toRad(b[1] - a[1]);
  const lat1 = toRad(a[0]), lat2 = toRad(b[0]);
  const s = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

export type HazardType =
  | "traffic_slowdown" | "collision" | "roadwork" | "debris"
  | "weather" | "closure" | "police" | "lane_restriction";

export type HazardSeverity = "low" | "medium" | "high" | "critical";

export const SEVERITY_COLOR: Record<HazardSeverity, string> = {
  low:    "#eab308",
  medium: "#f97316",
  high:   "#ef4444",
  critical:"#991b1b"
};

export const TYPE_ICON: Record<HazardType, string> = {
  traffic_slowdown: "triangle-alert",
  collision: "car-crash",
  roadwork: "cone",
  debris: "ban",
  weather: "cloud-lightning",
  closure: "octagon-alert",
  police: "badge-check",
  lane_restriction: "layout-panel-top"
};

export type Hazard = {
  id: string;
  type: HazardType;
  severity: HazardSeverity;
  status: "active" | "clearing" | "resolved" | "dismissed";
  title?: string | null;
  description?: string | null;
  lat: number;
  lng: number;
  detected_at: string;
  updated_at: string;
  fleet_id?: string | null;
  vehicle_id?: string | null;
  extra?: any;
};

export function filterHazardsForFleet(hazards: Hazard[], fleetId?: string | null, bbox?: BBox) {
  return hazards.filter(h => {
    const okFleet = !h.fleet_id || !fleetId || h.fleet_id === fleetId;
    const okBox = !bbox || inBBox(h.lat, h.lng, bbox);
    return okFleet && okBox && (h.status === "active" || h.status === "clearing");
  });
}

export function clusterByProximity(hazards: Hazard[], radiusM = 250): Hazard[][] {
  const clusters: Hazard[][] = [];
  const used = new Set<string>();
  for (const h of hazards) {
    if (used.has(h.id)) continue;
    const cluster = [h];
    used.add(h.id);
    for (const k of hazards) {
      if (used.has(k.id)) continue;
      if (h.type !== k.type) continue;
      const d = haversineDistanceMeters([h.lat, h.lng], [k.lat, k.lng]);
      if (d <= radiusM) {
        cluster.push(k);
        used.add(k.id);
      }
    }
    clusters.push(cluster);
  }
  return clusters;
}
