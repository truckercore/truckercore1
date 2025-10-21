export type DesktopRole = "owner-operator" | "fleet-manager" | "freight-broker" | "truck-stop" | "generic";

export function getRoleFromURL(): DesktopRole | null {
  if (typeof window === "undefined") return null;
  const u = new URL(window.location.href);
  const role = u.searchParams.get("role") as DesktopRole | null;
  return role || null;
}
