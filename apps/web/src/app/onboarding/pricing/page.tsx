"use client";
import React from "react";
import { useSearchParams } from "next/navigation";

export default function Pricing() {
  const sp = useSearchParams();
  const org = sp.get("org")!;
  const role = sp.get("role")!;
  const pending = sp.get("pending") === "1";

  const checkout = async (tier: string) => {
    const r = await fetch("/api/stripe/create-checkout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ org_id: org, role, tier }),
    });
    const j = await r.json();
    if (j.url) window.location.href = j.url;
  };

  return (
    <div style={{ padding: 24 }}>
      <h1>Select your plan</h1>
      {pending && <div style={{ color: "#F9A825" }}>Some checks are pending; you can proceed and we’ll finalize after verification.</div>}
      <div style={{ display: "grid", gap: 12, maxWidth: 600 }}>
        {["Basic","Standard","Premium","Enterprise"].map((t) => (
          <div key={t} style={{ border: "1px solid #444", padding: 16, borderRadius: 8 }}>
            <h3>{t}</h3>
            <button onClick={() => checkout(t)}>Continue to Checkout</button>
          </div>
        ))}
      </div>
    </div>
  );
}
