// TypeScript
import React from "react";
import { playGuidance } from "@/lib/audio/tts";
import { t } from "@/lib/i18n/strings";

export function DriverAckButton({
  alertId,
  driverId,
  orgId,
  suggestedSpeedKph,
  locale = "en",
}: {
  alertId: string;
  driverId: string;
  orgId: string;
  suggestedSpeedKph?: number;
  locale?: "en" | "es" | "fr";
}) {
  const onAck = async () => {
    const msg = `${t("slowdownAhead", locale)}. ${t("followSpeed", locale)} ${suggestedSpeedKph ?? ""}`.trim();
    playGuidance(msg, "calm", locale === "en" ? "en-US" : locale === "es" ? "es-ES" : "fr-FR");

    try {
      const fnBase = process.env.NEXT_PUBLIC_SUPABASE_FUNCTIONS_URL || `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1`;
      await fetch(`${fnBase}/alerts-ack`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          alert_id: alertId,
          driver_id: driverId,
          org_id: orgId,
          chosen_speed_kph: suggestedSpeedKph,
        }),
      });
    } catch {
      // ignore network errors in UI
    }
  };

  return (
    <button className="btn btn-primary" onClick={onAck} aria-label="Acknowledge">
      Acknowledge
    </button>
  );
}
