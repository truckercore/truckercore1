"use client";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend } from "recharts";

export default function ROIChart({ orgId }: { orgId: string }) {
  const [rows, setRows] = useState<any[]>([]);
  useEffect(()=>{ (async()=>{
    const { data } = await supabase
      .from("org_metrics_daily")
      .select("date, miles, revenue_usd")
      .eq("org_id", orgId)
      .order("date", { ascending: true });
    setRows(data ?? []);
  })(); },[orgId]);

  return (
    <div className="p-4 rounded-2xl shadow h-80">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={rows}>
          <XAxis dataKey="date"/>
          <YAxis yAxisId="left"/>
          <YAxis yAxisId="right" orientation="right"/>
          <Tooltip/>
          <Legend/>
          <Line yAxisId="left" type="monotone" dataKey="revenue_usd" name="Revenue" dot={false}/>
          <Line yAxisId="right" type="monotone" dataKey="miles" name="Miles" dot={false}/>
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
