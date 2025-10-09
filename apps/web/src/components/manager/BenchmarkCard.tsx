// TypeScript
import useSWR from "swr";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

async function fetchBench(corridor_id: string) {
  const { data, error } = await supabase
    .from("kpi_benchmark_corridor")
    .select("*")
    .eq("corridor_id", corridor_id)
    .order("day", { ascending: false })
    .limit(1);
  if (error) throw error;
  return data?.[0];
}

export function BenchmarkCard({
  corridorId,
  orgAckRate,
  orgP50,
  orgP95,
}: {
  corridorId: string;
  orgAckRate: number | null;
  orgP50: number | null;
  orgP95: number | null;
}) {
  const { data: b } = useSWR(["bench", corridorId], () => fetchBench(corridorId));
  const orgAckPct = orgAckRate !== null ? (orgAckRate * 100).toFixed(1) : "—";
  const benchAckPct = b?.median_ack_rate != null ? (b.median_ack_rate * 100).toFixed(1) : "—";
  return (
    <div className="p-4 rounded-2xl shadow bg-white dark:bg-zinc-900">
      <div className="text-sm opacity-60">Corridor {corridorId} Benchmark</div>
      <div className="mt-2 grid grid-cols-3 gap-3 text-sm">
        <div>
          <div className="opacity-60">Ack Rate</div>
          <div className="font-semibold">
            {orgAckPct}% vs {benchAckPct}%
          </div>
        </div>
        <div>
          <div className="opacity-60">P50 Ack</div>
          <div className="font-semibold">{orgP50 ?? "—"} ms vs {b?.median_p50_ack_ms ?? "—"} ms</div>
        </div>
        <div>
          <div className="opacity-60">P95 Ack</div>
          <div className="font-semibold">{orgP95 ?? "—"} ms vs {b?.median_p95_ack_ms ?? "—"} ms</div>
        </div>
      </div>
    </div>
  );
}
