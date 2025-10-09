"use client";
import React from "react";
import { useRouter } from "next/navigation";

const roles = [
  { key: "owner_operator", label: "Owner-Operator" },
  { key: "fleet_manager", label: "Fleet Manager (Carrier)" },
  { key: "truck_stop_admin", label: "Corporate Truck Stop" },
  { key: "broker", label: "Freight Broker" },
];

export default function PickRole() {
  const router = useRouter();
  return (
    <div style={{ padding: 24 }}>
      <h1>Choose your role</h1>
      <div style={{ display: "grid", gap: 12 }}>
        {roles.map((r) => (
          <button key={r.key} onClick={() => router.push(`/onboarding/credentials?role=${r.key}`)}>
            {r.label}
          </button>
        ))}
      </div>
    </div>
  );
}
