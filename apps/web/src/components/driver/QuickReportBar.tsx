"use client";
import React, { useState } from "react";

const PRESETS = [
  { key: "ACCIDENT", label: "Accident" },
  { key: "DEBRIS", label: "Debris" },
  { key: "SPEED_TRAP", label: "Police" },
  { key: "CONSTRUCTION", label: "Construction" },
  { key: "EMERGENCY_VEHICLE", label: "Emergency" },
];

export default function QuickReportBar() {
  const [sending, setSending] = useState(false);

  async function send(raw_label: string) {
    try {
      setSending(true);
      const pos = await new Promise<GeolocationPosition>((res, rej) =>
        navigator.geolocation.getCurrentPosition(res, rej, {
          enableHighAccuracy: true,
        })
      );
      const body = {
        lon: pos.coords.longitude,
        lat: pos.coords.latitude,
        raw_label,
      };
      await fetch("/api/report", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="flex gap-2 p-2">
      {PRESETS.map((p) => (
        <button
          key={p.key}
          onClick={() => send(p.label)}
          disabled={sending}
          className="rounded-2xl px-3 py-2 shadow bg-neutral-800 text-white"
        >
          {p.label}
        </button>
      ))}
      <button
        onClick={() => startVoice(send)}
        disabled={sending}
        className="rounded-2xl px-3 py-2 shadow bg-neutral-700 text-white"
        aria-label="Start voice report"
        title="Start voice report"
      >
        🎤
      </button>
    </div>
  );
}

function startVoice(cb: (text: string) => void) {
  // Simple Web Speech API (Android Chrome supported)
  const w = window as any;
  const Ctor = w.webkitSpeechRecognition || w.SpeechRecognition;
  if (!Ctor) {
    alert("Voice not supported");
    return;
  }
  const rec = new Ctor();
  rec.lang = "en-US";
  rec.interimResults = false;
  rec.maxAlternatives = 1;
  rec.onresult = (e: any) => cb(e?.results?.[0]?.[0]?.transcript ?? "");
  rec.onerror = () => {};
  rec.start();
}
