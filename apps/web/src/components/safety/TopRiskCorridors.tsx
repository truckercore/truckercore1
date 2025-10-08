// TypeScript
"use client";
import { useEffect, useState } from "react";
import { createClientComponentClient } from "@supabase/auth-helpers-nextjs";

type Row = { corridor_id: string; incidents: number; high_or_worse: number };

export default function TopRiskCorridors() {
  const supabase = createClientComponentClient();
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      setLoading(true); setErr(null);
      const { data, error } = await supabase
        .from("corridor_risk_daily")
        .select("corridor_id, incidents, high_or_worse")
        .order("high_or_worse", { ascending: false })
        .limit(10);
      if (error) setErr(error.message);
      else setRows(data ?? []);
      setLoading(false);
    })();
  }, [supabase]);

  if (loading) return <div className="p-4 rounded-lg border">Loading top corridors…</div>;
  if (err) return <div className="p-4 rounded-lg border text-red-600">{err}</div>;
  if (!rows.length) return <div className="p-4 rounded-lg border">No corridor data yet.</div>;

  return (
    <div className="p-4 rounded-lg border">
      <div className="font-semibold mb-2">Top Risk Corridors</div>
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-gray-600">
            <th className="py-1">Corridor</th>
            <th className="py-1">Incidents</th>
            <th className="py-1">High+</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.corridor_id} className="border-t">
              <td className="py-1">{r.corridor_id}</td>
              <td className="py-1">{r.incidents}</td>
              <td className="py-1">{r.high_or_worse}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
