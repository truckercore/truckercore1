"use client";
import React from "react";

export default function KpiBar({ k }: { k?: any }) {
  if (!k) return null;
  const pct = (x?: number) => (x == null ? "—" : `${Math.round(x * 100)}%`);
  return (
    <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
      <Card label="Alerts (today)" value={k.alerts_total ?? "—"} />
      <Card label="Active Peak" value={k.alerts_active_max ?? "—"} />
      <Card label="P95 Latency" value={k.p95_latency_ms ? `${k.p95_latency_ms} ms` : "—"} />
      <Card label="Ack Rate" value={pct(k.driver_ack_rate)} />
      <Card label="System Uptime" value={pct(k.system_uptime)} />
    </div>
  );
}

function Card({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-black/10 p-3 bg-white">
      <div className="text-xs opacity-60">{label}</div>
      <div className="text-xl font-semibold">{value}</div>
    </div>
  );
}
