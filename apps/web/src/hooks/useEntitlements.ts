import { useMemo } from "react";
import { entitlementsForPlan } from "@/lib/entitlements";

export function useEntitlements() {
  // Replace with your session hook if available; fallback to localStorage plan
  const plan = typeof window !== "undefined" ? window.localStorage.getItem("plan") : null;
  return useMemo(() => entitlementsForPlan(plan), [plan]);
}
