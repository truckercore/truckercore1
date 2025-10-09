import React from "react";
import maplibregl, { Map as MLMap } from "maplibre-gl";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

function useDebounced<T>(value: T, delay = 250): T {
  const [v, setV] = React.useState(value);
  React.useEffect(() => {
    const t = setTimeout(() => setV(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return v as T;
}

type Row = {
  id: number;
  org_id: string;
  name: string | null;
  risk_score: number;
  notes: string | null;
  updated_at: string;
  created_at: string;
  geojson: any;
};

export const TopRiskCorridors: React.FC<{ orgId: string }> = ({ orgId }) => {
  const containerRef = React.useRef<HTMLDivElement | null>(null);
  const mapRef = React.useRef<MLMap | null>(null);
  const [rows, setRows] = React.useState<Row[]>([]);
  const [count, setCount] = React.useState(0);
  const [serverTime, setServerTime] = React.useState<string | null>(null);
  const [zoom, setZoom] = React.useState<number>(3.5);
  const dZoom = useDebounced(zoom, 200);

  React.useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: "https://demotiles.maplibre.org/style.json",
      center: [-96, 38],
      zoom: 3.5,
    });
    mapRef.current = map;
    map.on("moveend", () => {
      setZoom(map.getZoom());
    });
  }, []);

  React.useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const b = map.getBounds();
    if (!b) return;
    const bbox: [number, number, number, number] = [b.getWest(), b.getSouth(), b.getEast(), b.getNorth()];

    (async () => {
      const { data, error } = await supabase.rpc("rpc_corridors_bounded", {
        p_org: orgId,
        p_bbox: bbox.join(","),
        p_limit: 500,
        p_cursor: null,
      });
      if (error) {
        console.error(error);
        setRows([]);
        return;
      }
      const r = (data as Row[]) || [];
      setRows(r);
      setCount(r.length);
      setServerTime(new Date().toISOString().slice(11, 16) + "Z");

      // Build FeatureCollection
      const fc: GeoJSON.FeatureCollection = {
        type: "FeatureCollection",
        features: r
          .map((row) => ({
            type: "Feature",
            geometry: typeof row.geojson === "string" ? JSON.parse(row.geojson) : row.geojson,
            properties: { id: row.id, risk_score: row.risk_score },
          })) as any,
      };

      const sourceId = "corridors";
      const src = map.getSource(sourceId) as any;
      if (src) src.setData(fc);
      else {
        map.addSource(sourceId, { type: "geojson", data: fc });
        map.addLayer({
          id: "corridor-line",
          type: "line",
          source: sourceId,
          paint: {
            "line-color": [
              "interpolate", ["linear"], ["get", "risk_score"],
              0, "#2E7D32",
              0.2, "#F9A825",
              0.5, "#EF6C00",
              0.8, "#C62828"
            ],
            "line-width": 3,
            "line-opacity": 0.8
          }
        });
      }
    })();
  }, [orgId, dZoom]);

  const top5 = [...rows].sort((a, b) => (b.risk_score || 0) - (a.risk_score || 0)).slice(0, 5);

  return (
    <div>
      <h3>Top 5 Risk Corridors</h3>
      <div ref={containerRef} style={{ height: 360, borderRadius: 8, overflow: "hidden", marginBottom: 12 }} />
      <div style={{ fontSize: 12, opacity: 0.75, marginBottom: 8 }}>
        {count} segments · updated {serverTime || "-"}
      </div>
      <table>
        <thead>
          <tr><th>#</th><th>Risk</th><th>ID</th></tr>
        </thead>
        <tbody>
          {top5.map((r, i) => (
            <tr key={String(r.id || i)}>
              <td>{i + 1}</td>
              <td>{String(r.risk_score || 0)}</td>
              <td>{String(r.id || "-")}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
