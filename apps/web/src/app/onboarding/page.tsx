"use client";
import React, { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

const roles = [
  { key: "driver",         label: "Driver",                  path: "/driver-dashboard" },
  { key: "owner_operator", label: "Owner-Operator",          path: "/owner-operator" },
  { key: "fleet_manager",  label: "Fleet Manager (Carrier)", path: "/fleet-manager" },
  { key: "broker",         label: "Freight Broker",          path: "/freight-broker-dashboard" },
];

export default function PickRole() {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);

  const handleSelect = async (role: string, path: string) => {
    setLoading(role);
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { router.replace("/login"); return; }

    await supabase
      .from("profiles")
      .upsert({ user_id: user.id, role, full_name: user.email }, { onConflict: "user_id" });

    window.location.href = path;
  };

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center">
      <div className="bg-gray-900 border border-gray-800 rounded-2xl p-8 w-full max-w-md">
        <h1 className="text-2xl font-bold text-white mb-2">Welcome to TruckerCore</h1>
        <p className="text-gray-400 text-sm mb-6">Choose your role to get started</p>
        <div className="grid gap-3">
          {roles.map((r) => (
            <button
              key={r.key}
              onClick={() => handleSelect(r.key, r.path)}
              disabled={!!loading}
              className="w-full bg-gray-800 hover:bg-gray-700 disabled:opacity-50 border border-gray-700 text-white font-medium rounded-lg py-3 transition"
            >
              {loading === r.key ? "Setting up..." : r.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
