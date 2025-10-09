"use client";
import React from "react";
import { createClient } from "@supabase/supabase-js";

type Row = { id: string; type: string; title?: string | null; detected_at: string; status?: string | null };

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function HazardModerationPage() {
  const [rows, setRows] = React.useState<Row[]>([]);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    (async () => {
      setLoading(true);
      const { data, error } = await supabase
        .from("hazards")
        .select("id,type,title,detected_at,status")
        .order("detected_at", { ascending: false })
        .limit(100);
      if (!error) setRows((data ?? []) as any);
      setLoading(false);
    })();
  }, []);

  const setLabel = async (id: string, label: "true" | "false") => {
    const { error } = await supabase.from("hazards").update({ status: label }).eq("id", id);
    if (!error) setRows((r) => r.map((x) => (x.id === id ? { ...x, status: label } : x)));
  };

  return (
    <div className="p-4">
      <h2 className="text-lg font-semibold mb-3">Hazard Moderation</h2>
      {loading ? (
        <div className="opacity-60 text-sm">Loading…</div>
      ) : (
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left opacity-60">
              <th className="py-2">Title</th>
              <th>Type</th>
              <th>Detected</th>
              <th>Status</th>
              <th>Label</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id} className="border-t">
                <td className="py-2">{r.title ?? r.id}</td>
                <td>{r.type}</td>
                <td>{new Date(r.detected_at).toLocaleString()}</td>
                <td>{r.status ?? "—"}</td>
                <td className="space-x-2">
                  <button className="px-2 py-1 rounded bg-green-50 border border-green-200" onClick={() => setLabel(r.id, "true")}>
                    True
                  </button>
                  <button className="px-2 py-1 rounded bg-red-50 border border-red-200" onClick={() => setLabel(r.id, "false")}>
                    False
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
