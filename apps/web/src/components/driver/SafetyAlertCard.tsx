// TypeScript
import { useState } from "react";

export function SafetyAlertCard(props: {
  alert: { id: string; kind: string; distance_ahead_m: number; suggested_speed_kph?: number };
  driver: { id: string; org_id: string };
  locale: string;
}) {
  const [acked, setAcked] = useState(false);
  const [chosen, setChosen] = useState(props.alert.suggested_speed_kph ?? 90);

  const onAck = async () => {
    setAcked(true);
    try {
      await fetch("/api/ack", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          alert_id: props.alert.id,
          driver_id: props.driver.id,
          org_id: props.driver.org_id,
          chosen_speed_kph: chosen,
        }),
      });
    } catch {}
  };

  return (
    <div className="p-4 rounded-2xl shadow bg-white dark:bg-zinc-900 border">
      <div className="text-lg font-semibold">Slowdown ahead</div>
      <div className="text-sm opacity-70">{Math.round(props.alert.distance_ahead_m)} m</div>

      {!acked ? (
        <button className="mt-3 px-4 py-2 rounded-xl bg-amber-500 text-white" onClick={onAck}>
          Acknowledge
        </button>
      ) : (
        <div className="mt-3 space-y-2">
          <label className="block text-sm">
            Recommended: {props.alert.suggested_speed_kph ?? "—"} kph
          </label>
          <input
            type="range"
            min="60"
            max="110"
            value={chosen}
            onChange={(e) => setChosen(parseInt(e.target.value))}
            className="w-full"
          />
          <button className="px-4 py-2 rounded-xl bg-emerald-600 text-white">Follow Guidance</button>
        </div>
      )}
    </div>
  );
}
