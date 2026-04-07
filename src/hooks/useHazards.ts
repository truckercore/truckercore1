// TypeScript
"use client";
import { useEffect, useMemo, useState } from "react";
import { createClient } from "@supabase/supabase-js";
import type { BBox, Hazard } from "@/lib/geo";
import { filterHazardsForFleet } from "@/lib/geo";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

type Opts = { fleetId?: string | null; bbox?: BBox };

export function useHazards(opts: Opts = {}) {
  const [hazards, setHazards] = useState<Hazard[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    (async () => {
      const { data, error } = await supabase
        .from("hazards")
        .select("*")
        .in("status", ["active","clearing"]) as any;
      if (!mounted) return;
      if (error) console.error(error);
      setHazards((data ?? []) as Hazard[]);
      setLoading(false);
    })();

    const ch = supabase
      .channel("hazard_changes")
      .on("postgres_changes", { event: "*", schema: "public", table: "hazards" }, (payload: any) => {
        setHazards((prev) => {
          const copy = [...prev];
          if (payload.eventType === "INSERT") {
            copy.unshift(payload.new as Hazard);
            return copy.slice(0, 500);
          }
          if (payload.eventType === "UPDATE") {
            const i = copy.findIndex(h => h.id === (payload.new as any).id);
            if (i >= 0) copy[i] = payload.new as Hazard;
            return copy;
          }
          if (payload.eventType === "DELETE") {
            return copy.filter(h => h.id !== (payload.old as any).id);
          }
          return copy;
        });
      })
      .subscribe();

    return () => {
      supabase.removeChannel(ch);
      mounted = false;
    };
  }, []);

  const filtered = useMemo(() => filterHazardsForFleet(hazards, opts.fleetId ?? null, opts.bbox), [hazards, opts.fleetId, JSON.stringify(opts.bbox)]);

  return { hazards: filtered, all: hazards, loading };
}

export function useHazardKpis(day?: string) {
  const [data, setData] = useState<any | null>(null);
  useEffect(() => {
    (async () => {
      const { data, error } = await supabase
        .from("hazard_kpis_daily")
        .select("*")
        .eq("day", day ?? new Date().toISOString().slice(0,10))
        .maybeSingle();
      if (error) console.error(error);
      setData(data ?? null);
    })();
  }, [day]);
  return data;
}
