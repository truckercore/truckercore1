import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Shared DB helpers for Truck Stops functions
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

export const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

export type Driver = { id: string };

// Placeholder: In production, use a materialized view or table with driver last location
// and perform a proper geospatial query (e.g., PostGIS earthdistance or geometry).
export async function getNearbyDrivers(truck_stop_id: string, radiusMiles: number): Promise<Driver[]> {
  // TODO: Implement using driver location table. For now return empty list to avoid unintended spam.
  console.warn("getNearbyDrivers stub called for truck_stop_id", truck_stop_id, "radius", radiusMiles);
  return [];
}

export async function sendPromotionNotification(driverId: string, promoId: string) {
  // TODO: Integrate with push notification service (FCM/APNs) or Supabase Realtime channel.
  console.log(`sendPromotionNotification -> driver:${driverId} promo:${promoId}`);
  return { ok: true };
}

export async function insertParkingSignal(payload: {
  truck_stop_id: string;
  available_spots: number;
  total_spots: number;
  reported_by: "iot_sensor" | "operator" | "driver" | string;
  premium_details?: Record<string, unknown> | null;
}) {
  const source_confidence = payload.reported_by === "iot_sensor" ? 100 : (payload.reported_by === "operator" ? 70 : 50);
  const { error } = await supabaseAdmin.from("parking_signals").insert({
    truck_stop_id: payload.truck_stop_id,
    available_spots: payload.available_spots,
    total_spots: payload.total_spots,
    reported_by: payload.reported_by,
    source_confidence,
    premium_details: payload.premium_details ?? null,
  });
  if (error) throw error;
  return { ok: true };
}

export async function getLatestReviews(truck_stop_id: string, limit = 30) {
  const { data, error } = await supabaseAdmin
    .from("truck_stop_reviews")
    .select("id, cleanliness, amenities, parking, food, overall, comment, created_at")
    .eq("truck_stop_id", truck_stop_id)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return data ?? [];
}
