"use client";
import React from "react";

export function AlertWhy({ ctx }: { ctx: any }) {
  if (!ctx) return null;
  return (
    <div className="text-xs opacity-70 mt-1">
      {ctx.report_id && (
        <>
          Crowd-verified • {ctx.confidence?.toFixed?.(2)} confidence • trust {ctx.trust_weight?.toFixed?.(2)}
        </>
      )}
      {ctx.fence_id && <> • Geofence match #{ctx.fence_id}</>}
      {ctx.fatigue && <> • Escalated due to driver fatigue</>}
    </div>
  );
}
