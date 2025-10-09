// Node 20+ has global fetch & performance
const ROUNDS = Number(process.env.ROUNDS ?? 50);
const LAT = Number(process.env.LAT ?? 32.9);
const LNG = Number(process.env.LNG ?? -97.0);
const RADIUS = Number(process.env.RADIUS ?? 200);
const BASE = process.env.BASE_URL ?? "http://localhost:3000";
const URL = process.env.URL ?? `${BASE}/api/optimizer/deadhead`;

(async () => {
  const t = [];
  for (let i = 0; i < ROUNDS; i++) {
    const s = performance.now();
    const res = await fetch(URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ current: { lat: LAT, lng: LNG }, radiusMiles: RADIUS })
    });
    try { await res.arrayBuffer(); } catch { /* ignore */ }
    t.push(performance.now() - s);
  }
  t.sort((a, b) => a - b);
  const p50 = t[Math.floor(ROUNDS * 0.5)] ?? 0;
  const p95 = t[Math.floor(ROUNDS * 0.95)] ?? 0;
  const min = t[0] ?? 0;
  const max = t[t.length - 1] ?? 0;
  console.log(JSON.stringify({
    rounds: ROUNDS,
    url: URL,
    min: Math.round(min),
    median: Math.round(p50),
    p95: Math.round(p95),
    max: Math.round(max)
  }, null, 2));
})();