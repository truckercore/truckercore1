// TypeScript
"use client";
import { useState } from "react";

export default function ExportAlertsCSVButton() {
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  async function doExport() {
    setLoading(true); setErr(null); setOk(false);
    try {
      const u = new URL("/api/exports/alerts", window.location.origin);
      const res = await fetch(u.toString(), { method: "GET", credentials: "include" });
      if (!res.ok) {
        const m = await res.json().catch(() => ({}));
        throw new Error(m?.error || `Export failed (${res.status})`);
      }
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "alerts.csv";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      setOk(true);
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex items-center gap-3">
      <button
        onClick={doExport}
        disabled={loading}
        className="px-3 py-2 rounded-md border hover:bg-gray-50 disabled:opacity-50"
        aria-busy={loading}
      >
        {loading ? "Exporting…" : "Export Alerts (CSV)"}
      </button>
      {ok && <span className="text-green-700 text-sm">Downloaded.</span>}
      {err && <span className="text-red-600 text-sm">{err}</span>}
    </div>
  );
}
