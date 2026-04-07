// TypeScript
export function classify(raw: string): { event_type: string; confidence: number } {
  const s = raw.toLowerCase();
  if (/(accident|crash|wreck)/.test(s)) return { event_type: "ACCIDENT", confidence: 0.9 };
  if (/(debris|tire|ladder|object)/.test(s)) return { event_type: "DEBRIS", confidence: 0.8 };
  if (/(police|speed trap)/.test(s)) return { event_type: "SPEED_TRAP", confidence: 0.7 };
  if (/(closure|closed|detour|construction|work zone)/.test(s)) {
    return /construction|work/.test(s)
      ? { event_type: "CONSTRUCTION", confidence: 0.7 }
      : { event_type: "ROAD_CLOSURE", confidence: 0.7 };
  }
  if (/(low bridge|clearance)/.test(s)) return { event_type: "LOW_BRIDGE", confidence: 0.8 };
  if (/(hazmat)/.test(s)) return { event_type: "HAZMAT_RESTRICTION", confidence: 0.8 };
  if (/(storm|ice|snow|hail|tornado|flood)/.test(s)) return { event_type: "WEATHER", confidence: 0.7 };
  return { event_type: "ACCIDENT", confidence: 0.4 }; // default conservative
}

export function expiryFor(event_type?: string) {
  const mins: Record<string, number> = {
    ACCIDENT: 90, DEBRIS: 45, SPEED_TRAP: 60, POLICE_ACTIVITY: 60,
    EMERGENCY_VEHICLE: 30, CONSTRUCTION: 240, ROAD_CLOSURE: 720,
    HAZMAT_RESTRICTION: 1440, LOW_BRIDGE: 365*24*60, WEATHER: 120
  };
  return event_type ? new Date(Date.now() + (mins[event_type] ?? 60) * 60000).toISOString() : null;
}
