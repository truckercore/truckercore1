// TypeScript
import React from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

type Row = {
  day: string;
  corridor_id: string | null;
  ack_rate: number | null;
  p50_ack_latency_ms: number | null;
  p95_ack_latency_ms: number | null;
};

type Bench = {
  day: string;
  corridor_id: string | null;
  median_ack_rate: number | null;
  median_p50_ack_ms: number | null;
  median_p95_ack_ms: number | null;
};

export function BenchmarkCards({ orgId, day }: { orgId: string; day: string }) {
  const [mine, setMine] = React.useState<Row[]>([]);
  const [bench, setBench] = React.useState<Bench[]>([]);

  React.useEffect(() => {
    (async () => {
      const { data: a } = await supabase
        .from("kpi_daily")
        .select("day,corridor_id,ack_rate,p50_ack_latency_ms,p95_ack_latency_ms")
        .eq("org_id", orgId)
        .eq("day", day)
        .limit(1000);
      setMine(a ?? []);
      const { data: b } = await supabase
        .from("kpi_benchmark_corridor")
        .select("*")
        .eq("day", day)
        .limit(1000);
      setBench(b ?? []);
    })();
  }, [orgId, day]);

  const rows = mine.map((r) => {
    const b = bench.find((x) => x.corridor_id === r.corridor_id);
    return { r, b };
  });

  return (
    <div style={{ display: "grid", gap: 12 }}>
      {rows.map(({ r, b }) => (
        <div key={r.corridor_id ?? "unknown"} className="card">
          <div className="card-header">{r.corridor_id ?? "Unknown Corridor"}</div>
          <div className="card-body" style={{ display: "flex", gap: 24 }}>
            <Metric label="Ack Rate" mine={r.ack_rate} bench={b?.median_ack_rate} fmt={(v) => `${Math.round((v ?? 0) * 100)}%`} />
            <Metric label="P50 Ack" mine={r.p50_ack_latency_ms} bench={b?.median_p50_ack_ms} fmt={(v) => `${v ?? 0} ms`} />
            <Metric label="P95 Ack" mine={r.p95_ack_latency_ms} bench={b?.median_p95_ack_ms} fmt={(v) => `${v ?? 0} ms`} />
          </div>
        </div>
      ))}
    </div>
  );
}

function Metric({
  label,
  mine,
  bench,
  fmt,
}: {
  label: string;
  mine: number | null | undefined;
  bench: number | null | undefined;
  fmt: (v: number | null | undefined) => string;
}) {
  const delta = mine != null && bench != null ? (mine as number) - (bench as number) : null;
  const deltaText =
    delta == null ? "" : `${delta >= 0 ? "+" : ""}${fmt(delta as number).replace(/[^0-9+.-]/g, "")}`;
  return (
    <div>
      <div style={{ fontWeight: 600 }}>{label}</div>
      <div>Fleet: {fmt(mine ?? 0)}</div>
      <div>Network: {fmt(bench ?? 0)}</div>
      <div style={{ opacity: 0.7 }}>Δ: {deltaText}</div>
    </div>
  );
}
