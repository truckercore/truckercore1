// TypeScript
"use client";
import React, { useEffect, useRef } from "react";
import mapboxgl from "mapbox-gl";
import { Hazard, SEVERITY_COLOR, TYPE_ICON } from "@/lib/geo";
import { AlertTriangle, CarCrash, Cone, Zap, OctagonAlert, BadgeCheck, LayoutPanelTop, Ban } from "lucide-react";
import ReactDOMServer from "react-dom/server";

(mapboxgl as any).accessToken = process.env.NEXT_PUBLIC_MAPBOX_TOKEN!;

const IconByName: Record<string, React.FC<any>> = {
  "triangle-alert": AlertTriangle,
  "car-crash": CarCrash,
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
  initialCenter?: [number, number]; // [lng, lat]
  initialZoom?: number;
};

export default function HazardMap({ hazards, onSelect, initialCenter = [-98.5, 39.8], initialZoom = 4 }: Props) {
  const ref = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<mapboxgl.Map | null>(null);

  useEffect(() => {
    if (!ref.current || mapRef.current) return;
    mapRef.current = new mapboxgl.Map({
      container: ref.current,
      style: "mapbox://styles/mapbox/streets-v12",
      center: initialCenter,
      zoom: initialZoom,
    });
  }, [ref.current]);

  useEffect(() => {
    if (!mapRef.current) return;
    (mapRef.current as any).__hazard_markers?.forEach((m: mapboxgl.Marker) => m.remove());
    (mapRef.current as any).__hazard_markers = [];

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

      const marker = new mapboxgl.Marker({ element: wrap })
        .setLngLat([h.lng, h.lat])
        .setPopup(new mapboxgl.Popup({ offset: 12 }).setHTML(`
            <div class="p-2">
              <div class="font-semibold">${h.title ?? h.type}</div>
              <div class="text-xs opacity-80">${h.description ?? ""}</div>
              <div class="text-xs mt-1">Severity: ${h.severity}</div>
              <div class="text-xs">Detected: ${new Date(h.detected_at).toLocaleString()}</div>
            </div>
        `))
        .addTo(mapRef.current!);

      marker.getElement().addEventListener("click", () => onSelect?.(h));
      (mapRef.current as any).__hazard_markers.push(marker);
    });
  }, [JSON.stringify(hazards)]);

  return <div ref={ref} className="w-full h-[480px] rounded-2xl overflow-hidden ring-1 ring-black/10" />;
}
