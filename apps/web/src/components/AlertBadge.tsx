"use client";
import React from "react";

export function AlertBadge({ severity }: { severity: "INFO" | "WARN" | "URGENT" }) {
  const cls =
    severity === "URGENT"
      ? "bg-red-600 text-white"
      : severity === "WARN"
      ? "bg-yellow-500 text-black"
      : "bg-gray-300 text-black";
  return (
    <span className={`px-2 py-0.5 rounded-full text-xs ${cls}`}>
      {severity}
    </span>
  );
}
