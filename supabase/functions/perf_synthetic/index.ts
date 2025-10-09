import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BASE = Deno.env.get("PUBLIC_EDGE_BASE")!; // e.g., https://<project>.functions.supabase.co

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

async function timeOnce(path: string) {
  const t0 = performance.now();
  let ok = false, status = 0;
  try {
    const res = await fetch(`${BASE}/${path}` , {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ synthetic: true }),
    });
    status = res.status;
    ok = res.ok;
  } catch {
    ok = false;
  }
  const ms = Math.round(performance.now() - t0);
  return { ok, ms, status };
}

function p95Of(nums: number[]): number {
  if (nums.length === 0) return 0;
  const arr = [...nums].sort((a, b) => a - b);
  const idx = Math.floor(0.95 * (arr.length - 1));
  return arr[idx] ?? 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  let body: any = {};
  try {
    body = await req.json();
  } catch { /* keep defaults */ }

  const n = Math.min(200, Math.max(10, Number(body.n) || 100));
  const concurrency = Math.min(10, Math.max(1, Number(body.c) || 5));
  const paceMs = Math.min(1000, Math.max(0, Number(body.pace_ms) || 0));

  // Budgets (ms)
  const budgets: Record<string, number> = {
    suggest: 500,
    propose: 800,
    apply: 800,
  };

  // Endpoints to probe (relative to PUBLIC_EDGE_BASE)
  const runs: Array<{ ep: "suggest" | "propose" | "apply"; path: string; budget: number }> = [
    { ep: "suggest", path: "suggest", budget: budgets.suggest },
    { ep: "propose", path: "propose", budget: budgets.propose },
    { ep: "apply", path: "apply", budget: budgets.apply },
  ];

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);
  const results: any = {};

  for (const r of runs) {
    const latencies: number[] = [];
    let i = 0;
    while (i < n) {
      const wave = Math.min(concurrency, n - i);
      const batch = Array.from({ length: wave }, () => timeOnce(r.path));
      const waveRes = await Promise.all(batch);
      i += wave;

      // best-effort logging to perf.events
      const rows = waveRes.map(({ ok, ms, status }) => ({
        endpoint: r.ep,
        latency_ms: ms,
        ok,
        synthetic: true,
        device: "synthetic",
        network: "na",
        route: r.path,
        error_code: ok ? null : `HTTP_${status || 0}`,
      }));
      admin.from("perf.events").insert(rows).catch(() => void 0);

      latencies.push(...waveRes.map((x) => x.ms));
      if (paceMs > 0) await new Promise((res) => setTimeout(res, paceMs));
    }

    const p95 = Math.round(p95Of(latencies));
    results[r.ep] = { n, p95_ms: p95, budget_ms: r.budget, pass: p95 <= r.budget };
  }

  return json({ results });
});
