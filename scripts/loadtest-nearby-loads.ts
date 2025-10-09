import fetch from "node-fetch";

const ROUNDS = Number(process.env.ROUNDS ?? 100);
const LAT = Number(process.env.LAT ?? 32.9);
const LNG = Number(process.env.LNG ?? -97.0);
const RADIUS = Number(process.env.RADIUS ?? 200);
const URL = process.env.URL ?? "http://localhost:3000/api/optimizer/deadhead";

(async () => {
  const t: number[] = [];
  for (let i = 0; i < ROUNDS; i++) {
    const s = performance.now();
    const res = await fetch(URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ current: { lat: LAT, lng: LNG }, radiusMiles: RADIUS })
    });
    // Drain body to not skew timing on next request
    await res.arrayBuffer();
    t.push(performance.now() - s);
  }
  t.sort((a, b) => a - b);
  const p50 = t[Math.floor(ROUNDS * 0.5)];
  const p95 = t[Math.floor(ROUNDS * 0.95)];
  const min = t[0];
  const max = t[t.length - 1];
  console.log(JSON.stringify({
    rounds: ROUNDS,
    url: URL,
    min: Math.round(min),
    median: Math.round(p50),
    p95: Math.round(p95),
    max: Math.round(max)
  }, null, 2));
})();