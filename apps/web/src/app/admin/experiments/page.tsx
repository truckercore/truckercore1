"use client";
import { useEffect, useState } from "react";

type Row = {
  key: string; feature_key: string; env: string; status: string; start_at: string; end_at: string | null;
  weights: any; views_30d: number; clicks_30d: number; opens_30d: number; converts_30d: number;
  ctr_30d: number; checkout_conv_30d: number; e2e_conv_30d: number;
};

export default function ExperimentsAdmin() {
  const [rows, setRows] = useState<Row[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const adminToken = process.env.NEXT_PUBLIC_AB_ADMIN_TOKEN as string;

  async function load() {
    try {
      const r = await fetch("/functions/v1/ab_admin?action=list", { headers: { "X-Admin-Token": adminToken } });
      const j = await r.json(); if (j.status !== "ok") throw new Error(j.message);
      setRows(j.data.items);
    } catch (e: any) { setErr(String(e?.message ?? e)); }
  }
  useEffect(() => { load(); }, []);

  async function post(action: string, payload: any) {
    await fetch(`/functions/v1/ab_admin?action=${action}` ,{
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Admin-Token": adminToken },
      body: JSON.stringify(payload)
    });
    load();
  }

  return (
    <div className="p-6 space-y-4">
      <h1 className="text-2xl font-semibold">Experiments</h1>
      {err && <div className="text-red-600">Error: {err}</div>}
      <table className="min-w-full text-sm border">
        <thead className="bg-gray-50">
          <tr>
            <th className="p-2 text-left">Key</th>
            <th className="p-2">Feature</th>
            <th className="p-2">Env</th>
            <th className="p-2">Status</th>
            <th className="p-2">Weights</th>
            <th className="p-2">CTR</th>
            <th className="p-2">Checkout</th>
            <th className="p-2">E2E</th>
            <th className="p-2">Actions</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(r => (
            <tr key={r.key} className="border-t">
              <td className="p-2">{r.key}</td>
              <td className="p-2">{r.feature_key}</td>
              <td className="p-2">{r.env}</td>
              <td className="p-2">{r.status}</td>
              <td className="p-2 font-mono">{JSON.stringify(r.weights)}</td>
              <td className="p-2">{(r.ctr_30d * 100).toFixed(2)}%</td>
              <td className="p-2">{(r.checkout_conv_30d * 100).toFixed(2)}%</td>
              <td className="p-2">{(r.e2e_conv_30d * 100).toFixed(2)}%</td>
              <td className="p-2 space-x-2">
                <button className="px-2 py-1 bg-yellow-100" onClick={() => post("pause", { key: r.key })}>Pause</button>
                <button className="px-2 py-1 bg-gray-200" onClick={() => post("archive", { key: r.key })}>Archive</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
