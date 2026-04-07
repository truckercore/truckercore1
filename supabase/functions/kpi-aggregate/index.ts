// TypeScript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Cron: run hourly/daily
export const handler = async (_req: Request) => {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return new Response("Missing SUPABASE env", { status: 500 });

  const supabase = createClient(url, key);

  // Aggregate last 48h (buffer)
  const since = new Date(Date.now() - 1000 * 60 * 60 * 48).toISOString();

  // Fetch raw
  const { data: alerts, error: e1 } = await supabase
    .from("driver_alerts")
    .select("id, org_id, created_at, corridor_id")
    .gte("created_at", since);
  if (e1) return new Response(e1.message, { status: 500 });

  const { data: acks, error: e2 } = await supabase
    .from("driver_acks")
    .select("alert_id, org_id, latency_ms, created_at")
    .gte("created_at", since);
  if (e2) return new Response(e2.message, { status: 500 });

  const { data: near, error: e3 } = await supabase
    .from("near_misses")
    .select("org_id, created_at, corridor_id")
    .gte("created_at", since);
  if (e3) return new Response(e3.message, { status: 500 });

  type Key = string;
  const kpis = new Map<Key, any>();
  const keyOf = (d: Date, org: string, corridor?: string | null) =>
    `${d.toISOString().slice(0, 10)}|${org}|${corridor ?? "ALL"}`;

  (alerts ?? []).forEach((a: any) => {
    const day = new Date(a.created_at);
    const k = keyOf(day, a.org_id, a.corridor_id);
    const row =
      kpis.get(k) ??
      {
        day: day.toISOString().slice(0, 10),
        org_id: a.org_id,
        corridor_id: a.corridor_id,
        alerts: 0,
        acks: 0,
        latencies: [] as number[],
        near: 0,
      };
    row.alerts++;
    kpis.set(k, row);
  });

  (acks ?? []).forEach((x: any) => {
    const day = new Date(x.created_at);
    const k = keyOf(day, x.org_id, null);
    const row =
      kpis.get(k) ??
      {
        day: day.toISOString().slice(0, 10),
        org_id: x.org_id,
        corridor_id: null,
        alerts: 0,
        acks: 0,
        latencies: [] as number[],
        near: 0,
      };
    row.acks++;
    row.latencies.push(Number(x.latency_ms ?? 0));
    kpis.set(k, row);
  });

  (near ?? []).forEach((n: any) => {
    const day = new Date(n.created_at);
    const k = keyOf(day, n.org_id, n.corridor_id);
    const row =
      kpis.get(k) ??
      {
        day: day.toISOString().slice(0, 10),
        org_id: n.org_id,
        corridor_id: n.corridor_id,
        alerts: 0,
        acks: 0,
        latencies: [] as number[],
        near: 0,
      };
    row.near++;
    kpis.set(k, row);
  });

  function percentile(sorted: number[], p: number) {
    if (!sorted.length) return null as number | null;
    const idx = Math.max(0, Math.min(sorted.length - 1, Math.floor(sorted.length * p)));
    return sorted[idx] ?? null;
  }

  const rows = Array.from(kpis.values()).map((r) => {
    const sorted = [...r.latencies].sort((a, b) => a - b);
    const alerts = Number(r.alerts || 0);
    const acks = Number(r.acks || 0);
    return {
      day: r.day,
      org_id: r.org_id,
      corridor_id: r.corridor_id,
      alerts,
      acks,
      ack_rate: alerts > 0 ? acks / alerts : null,
      p50_ack_latency_ms: percentile(sorted, 0.5),
      p95_ack_latency_ms: percentile(sorted, 0.95),
      near_misses: Number(r.near || 0),
      speed_compliance_rate: null,
    };
  });

  if (rows.length) {
    const { error } = await supabase
      .from("kpi_daily")
      .upsert(rows, { onConflict: "day,org_id,corridor_id" });
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  // Refresh corridor medians (materialized view)
  try {
    await supabase.rpc("refresh_materialized_view", { view_name: "public.kpi_benchmark_corridor" });
  } catch (_) {}

  return new Response(JSON.stringify({ upserted: rows.length }), {
    headers: { "Content-Type": "application/json" },
  });
};

Deno.serve(handler);
