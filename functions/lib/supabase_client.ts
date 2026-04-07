import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { FuelCardTransaction } from "./external_fuel_api.ts";

// Read from environment in Supabase Edge Runtime
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.warn("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars.");
}

export const supabase = createClient(
  SUPABASE_URL ?? "",
  SUPABASE_SERVICE_ROLE_KEY ?? "",
  { global: { headers: { "x-application": "fuel-card-sync" } } },
);

export async function insertFuelTransactions(data: FuelCardTransaction[]) {
  if (!data || data.length === 0) return 0;

  // Map external data into DB table shape
  const rows = data.map((d) => ({
    truck_id: d.truck_id ?? null,
    driver_id: d.driver_id ?? null,
    gallons: d.gallons,
    total_cost: d.total_cost,
    location: d.location ?? null,
    fuel_time: d.fuel_time,
  }));

  const { error, count } = await supabase
    .from("fuel_transactions")
    .insert(rows, { count: "exact" });

  if (error) throw error;
  return count ?? rows.length;
}
