"use client";
import { useState } from "react";

export default function DeadheadFilterPanel() {
  const [radius, setRadius] = useState(200);
  const [minPPM, setMinPPM] = useState(2.0);
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  const run = async () => {
    setLoading(true);
    const res = await fetch("/api/optimizer/deadhead", { method: "POST", headers: {"Content-Type":"application/json"}, body: JSON.stringify({ current:{ lat:32.9, lng:-97.0 }, radiusMiles: radius }) });
    const json = await res.json();
    const filtered = (json.recommendations||[]).filter((r:any)=> (r.rate_usd/Math.max(r.miles,1)) >= minPPM);
    setRows(filtered);
    setLoading(false);
  };

  return (
    <div className="p-4 rounded-2xl shadow grid gap-3">
      <div className="grid grid-cols-2 gap-3">
        <label className="text-sm">Radius mi<input type="number" className="border rounded p-2 w-full" value={radius} onChange={e=>setRadius(Number(e.target.value))}/></label>
        <label className="text-sm">Min $/mi<input type="number" step="0.1" className="border rounded p-2 w-full" value={minPPM} onChange={e=>setMinPPM(Number(e.target.value))}/></label>
      </div>
      <button className="px-4 py-2 rounded-2xl shadow" onClick={run} disabled={loading}>{loading?"Finding…":"Find Loads"}</button>
      <ul className="space-y-2 max-h-80 overflow-auto">
        {rows.map((r:any)=> (
          <li key={r.id} className="p-3 rounded-xl border">
            <div className="font-medium">{r.origin_city} → {r.dest_city}</div>
            <div className="text-sm">Deadhead {r.distance_miles?.toFixed(1)} mi · Rate ${r.rate_usd} · Trip {r.miles} mi · ${(r.rate_usd/Math.max(r.miles,1)).toFixed(2)} $/mi</div>
          </li>
        ))}
      </ul>
    </div>
  );
}
