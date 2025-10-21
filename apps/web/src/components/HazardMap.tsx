"use client";
import React, { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";
import { Hazard, SEVERITY_COLOR, TYPE_ICON, BBox } from "@/lib/geo";
import { AlertTriangle, Car, Cone, Zap, OctagonAlert, BadgeCheck, LayoutPanelTop, Ban } from "lucide-react";
import ReactDOMServer from "react-dom/server";

const IconByName: Record<string, React.FC<any>> = {
  "triangle-alert": AlertTriangle,
  "car-crash": Car,
  "cone": Cone,
  "cloud-lightning": Zap,
  "octagon-alert": OctagonAlert,
  "badge-check": BadgeCheck,
  "layout-panel-top": LayoutPanelTop,
  "ban": Ban,
};

type Props = {
  hazards: Hazard[];
  onSelect?: (h: Hazard) => void;
  onBoundsChange?: (bbox?: BBox) => void;
  initialCenter?: [number, number]; // [lng, lat]
  initialZoom?: number;
};

export default function HazardMap({ hazards, onSelect, onBoundsChange, initialCenter = [-98.5, 39.8], initialZoom = 4 }: Props) {
  const ref = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);

  useEffect(() => {
    if (!ref.current || mapRef.current) return;
    const map = new maplibregl.Map({
      container: ref.current,
      style: "https://demotiles.maplibre.org/style.json",
      center: initialCenter,
      zoom: initialZoom,
    });
    mapRef.current = map;

    const emitBounds = () => {
      if (!onBoundsChange) return;
      const b = map.getBounds();
      if (!b) return;
      const bbox: BBox = [b.getWest(), b.getSouth(), b.getEast(), b.getNorth()];
      onBoundsChange(bbox);
    };

    map.on("load", () => emitBounds());
    map.on("moveend", () => emitBounds());

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, [ref.current]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    // Remove existing markers
    (map as any).__hazard_markers?.forEach((m: maplibregl.Marker) => m.remove());
    (map as any).__hazard_markers = [];

    hazards.forEach((h) => {
      const wrap = document.createElement("div");
      wrap.className = "flex items-center justify-center rounded-full shadow-lg";
      wrap.style.width = "28px";
      wrap.style.height = "28px";
      wrap.style.background = SEVERITY_COLOR[h.severity];

      const iconName = TYPE_ICON[h.type];
      const Icon = IconByName[iconName] ?? AlertTriangle;
      const svgHtml = ReactDOMServer.renderToStaticMarkup(<Icon color="white" size={18} />);

      const svg = document.createElement("div");
      svg.innerHTML = svgHtml;
      wrap.appendChild(svg);

      const marker = new maplibregl.Marker({ element: wrap })
        .setLngLat([h.lng, h.lat])
        .addTo(map);

      marker.getElement().addEventListener("click", () => onSelect?.(h));
      (map as any).__hazard_markers.push(marker);
    });
  }, [JSON.stringify(hazards)]);

  return <div ref={ref} className="w-full h-[480px] rounded-2xl overflow-hidden ring-1 ring-black/10" />;
}
