"use client";
import React from "react";
import { useAlerts } from "@/hooks/useAlerts";
import { useLocale } from "@/i18n/locale";
import { AlertWhy } from "@/components/AlertWhy";

export default function AlertToast() {
  const alerts = useAlerts();
  const { t } = useLocale();
  if (!alerts.length) return null;
  const a = alerts[0];

  const base =
    a.severity === "URGENT"
      ? "bg-red-600 text-white"
      : a.severity === "WARN"
      ? "bg-yellow-500 text-black"
      : "bg-gray-800 text-white";

  return (
    <div
      className={`fixed bottom-4 left-1/2 -translate-x-1/2 rounded-2xl p-4 shadow-lg ${base} max-w-[90vw]`}
      role="alert"
      aria-live="assertive"
    >
      <div className="font-bold">{t(a.title)}</div>
      <div className="text-sm opacity-90">{t(a.message)}</div>
      {a.context?.confidence && (
        <div className="text-xs opacity-70 mt-1">
          {t("why")}: {Number(a.context.confidence).toFixed(2)} {t("confidence")}
        </div>
      )}
      <AlertWhy ctx={a.context} />
    </div>
  );
}
