"use server";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function getNearbyLoads(lat: number, lng: number, radiusMiles = 200) {
  const cookieStore = cookies();
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { get: (k: string) => cookieStore.get(k)?.value } }
  );
  const { data, error } = await supabase.rpc("nearby_loads", { lat, lng, radius_miles: radiusMiles });
  if (error) throw new Error(error.message);
  return data ?? [];
}
