import React from "react";
import { useEntitlements } from "@/hooks/useEntitlements";

export const UpsellBanner: React.FC<{ feature: string; cta?: string }> = ({ feature, cta }) => {
  const ent = useEntitlements();
  if (ent.exportsMonthlyCap >= 200) return null; // already Pro+

  return (
    <div
      style={{
        background: "linear-gradient(90deg, #667eea 0%, #764ba2 100%)",
        color: "#fff",
        padding: 16,
        borderRadius: 8,
        marginBottom: 16,
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
      }}
    >
      <div>
        <strong>{feature}</strong> is part of TruckerCore Pro.
        {cta && <div style={{ fontSize: 14, marginTop: 4 }}>{cta}</div>}
      </div>
      <button
        style={{
          background: "#fff",
          color: "#667eea",
          border: "none",
          padding: "8px 16px",
          borderRadius: 6,
          fontWeight: 600,
          cursor: "pointer",
        }}
        onClick={() => (window.location.href = "/upgrade")}
      >
        Upgrade – $149/mo
      </button>
    </div>
  );
};
