"use client";
import { useEffect, useRef, useState } from "react";

export type AlertSeverity = "INFO" | "WARN" | "URGENT";
export type AlertItem = {
  id: string;
  title: string;
  message: string;
  severity: AlertSeverity;
  context?: any;
  created_at?: string;
};

export function useAlerts() {
  const [alerts, setAlerts] = useState<AlertItem[]>([]);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    async function tick() {
      try {
        const pos = await new Promise<GeolocationPosition>((res, rej) =>
          navigator.geolocation.getCurrentPosition(res, rej, {
            enableHighAccuracy: true,
            maximumAge: 5000,
          })
        );
        const r = await fetch("/api/alerts", {
          method: "POST",
          body: JSON.stringify({
            lon: pos.coords.longitude,
            lat: pos.coords.latitude,
            speed_kph: (pos.coords as any).speed ?? null,
          }),
          headers: { "Content-Type": "application/json" },
        });
        if (r.ok) {
          const json = await r.json();
          if (Array.isArray(json.alerts) && json.alerts.length) {
            setAlerts(json.alerts);
            playEscalation(json.alerts[0]?.severity);
          }
        }
      } catch {
        // ignore
      } finally {
        timer.current = setTimeout(tick, 15000);
      }
    }
    tick();
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, []);

  return alerts;
}

function playEscalation(sev: AlertSeverity | undefined) {
  if (!sev) return;
  const src =
    sev === "URGENT"
      ? "/sounds/urgent.mp3"
      : sev === "WARN"
      ? "/sounds/warn.mp3"
      : "/sounds/info.mp3";
  const audio = new Audio(src);
  audio.play().catch(() => {});
}
