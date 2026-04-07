export function canSee(type: string, premium: boolean) {
  const free = new Set([
    "ACCIDENT",
    "CONSTRUCTION",
    "ROAD_CLOSURE",
    "LOW_BRIDGE",
  ]);
  return premium ? true : free.has(type);
}
