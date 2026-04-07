// TypeScript
"use client";
import { useEffect, useState } from "react";
import { createBrowserClient } from "@supabase/ssr";

type SafetySummary = { summary_date: string; metrics: Record<string, number | string> };

export default function SafetySummaryCard() {
  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<SafetySummary | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      setLoading(true); setErr(null);
      const { data, error } = await supabase
        .from("safety_summaries")
        .select("summary_date, metrics")
        .order("summary_date", { ascending: false })
        .limit(1);
      if (error) setErr(error.message);
      else setData((data ?? [])[0] ?? null);
      setLoading(false);
    })();
  }, [supabase]);

  if (loading) return <div className="p-4 rounded-lg border">Loading safety summary…</div>;
  if (err) return <div className="p-4 rounded-lg border text-red-600">{err}</div>;
  if (!data) return <div className="p-4 rounded-lg border">No safety summary available.</div>;

  return (
    <div className="p-4 rounded-lg border">
      <div className="font-semibold">Safety Summary — {data.summary_date}</div>
      <ul className="mt-2 space-y-1 text-sm">
        {Object.entries(data.metrics).map(([k, v]) => (
          <li key={k} className="flex justify-between">
            <span className="text-gray-600">{k}</span>
            <span className="font-medium">{String(v)}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
