// TypeScript
import useSWR from "swr";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

async function fetchKpi(org_id: string) {
  const since = new Date(Date.now() - 1000 * 60 * 60 * 24 * 7).toISOString().slice(0, 10);
  const { data, error } = await supabase.from("kpi_daily").select("*").eq("org_id", org_id).gte("day", since);
  if (error) throw error;
  return data ?? [];
}

export function AckRateCard({ orgId }: { orgId: string }) {
  const { data } = useSWR(["kpi", orgId], () => fetchKpi(orgId));
  const alerts = (data ?? []).reduce((a: number, r: any) => a + (r.alerts || 0), 0);
  const acks = (data ?? []).reduce((a: number, r: any) => a + (r.acks || 0), 0);
  const ackRate = alerts ? (acks / alerts) * 100 : null;

  return (
    <div className="p-4 rounded-2xl shadow bg-white dark:bg-zinc-900">
      <div className="text-sm opacity-60">7-day Ack Rate</div>
      <div className="text-3xl font-bold">{ackRate !== null ? ackRate.toFixed(1) : "—"}%</div>
      <div className="text-xs opacity-60">Alerts {alerts} · Acks {acks}</div>
    </div>
  );
}
