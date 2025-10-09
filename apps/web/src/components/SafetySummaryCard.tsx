import React from "react";
import { createClient } from "@supabase/supabase-js";

type Summary = {
  org_id: string;
  summary_date: string;
  total_alerts: number;
  urgent_alerts: number;
  unique_drivers: number;
  top_types: Array<{ type: string; ct?: number; count?: number }>;
};

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

export const SafetySummaryCard: React.FC<{ orgId: string }> = ({ orgId }) => {
  const [rows, setRows] = React.useState<Summary[]>([]);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    let mounted = true;
    (async () => {
      setLoading(true);
      const since = new Date();
      since.setDate(since.getDate() - 7);
      const { data, error } = await supabase
        .from("safety_daily_summary")
        .select("*")
        .eq("org_id", orgId)
        .gte("summary_date", since.toISOString().slice(0, 10))
        .order("summary_date", { ascending: false });
      if (!mounted) return;
      if (error) {
        console.error(error);
        setRows([]);
      } else {
        setRows((data as any) ?? []);
      }
      setLoading(false);
    })();
    return () => { mounted = false };
  }, [orgId]);

  if (loading) return <div className="card">Loading safety summary…</div>;

  const totals = rows.reduce(
    (acc, r) => {
      acc.total += r.total_alerts;
      acc.urgent += r.urgent_alerts;
      acc.drivers = Math.max(acc.drivers, r.unique_drivers);
      return acc;
    },
    { total: 0, urgent: 0, drivers: 0 }
  );

  const typeCounts: Record<string, number> = {};
  rows.forEach((r) => {
    (r.top_types || []).forEach((t) => {
      const val = (t as any).count ?? (t as any).ct ?? 0;
      typeCounts[(t as any).type] = (typeCounts[(t as any).type] ?? 0) + val;
    });
  });
  const top5 = Object.entries(typeCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5);

  return (
    <div className="card">
      <div className="card-header">Safety (7 days)</div>
      <div className="card-body">
        <div style={{ display: "flex", gap: 16 }}>
          <Metric label="Alerts" value={totals.total} />
          <Metric label="Urgent" value={totals.urgent} />
          <Metric label="Drivers" value={totals.drivers} />
        </div>
        <div style={{ marginTop: 12 }}>
          <strong>Top Types</strong>
          <ul>
            {top5.map(([type, ct]) => (
              <li key={type}>
                {type}: {ct}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  );
};

const Metric: React.FC<{ label: string; value: number }> = ({ label, value }) => (
  <div>
    <div style={{ fontSize: 24, fontWeight: 700 }}>{value}</div>
    <div style={{ opacity: 0.75 }}>{label}</div>
  </div>
);
