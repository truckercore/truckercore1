import type { LatLng } from "./db.ts";

export async function roadDoggAiSuggestBestLoad(owner_op_id: string, loads: any[], origin: LatLng) {
  // Placeholder AI ranking logic:
  // Score by pay minus a simple deadhead estimate to origin (Euclidean approx)
  const scored = loads.map((l) => {
    const pay = Number(l.pay ?? 0);
    // In real system, convert origin/destination city to lat/lng and compute road distance
    const deadhead = Math.random() * 100; // TODO: replace with real distance calc
    const score = pay - deadhead * 1.0; // adjust weight as needed
    return { ...l, score, estimated_deadhead_miles: Math.round(deadhead) };
  });

  scored.sort((a, b) => (b.score ?? 0) - (a.score ?? 0));
  return {
    owner_op_id,
    origin,
    best_load: scored[0] ?? null,
    candidates: scored.slice(0, 10),
  };
}
