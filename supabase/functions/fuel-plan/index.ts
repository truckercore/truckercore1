// supabase/functions/fuel-plan/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
type FuelPlanReq = { org_id: string; load_id: string; asset_id: string; start_fuel_gal?: number; route_legs: { leg_index: number; miles: number; station_id?: string; lat?: number; lng?: number }[] };

export const handler = async (req: Request) => {
  try {
    const payload = (await req.json()) as FuelPlanReq;
    const { createClient } = await import("npm:@supabase/supabase-js");
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const { data: prof } = await sb.from("vehicle_fuel_profile").select("*").eq("org_id", payload.org_id).eq("asset_id", payload.asset_id).single();
    if (!prof) throw new Error("missing fuel profile");

    const stationIds = payload.route_legs.map((l) => l.station_id).filter(Boolean) as string[];
    const priceMap: Record<string, number> = {};
    if (stationIds.length) {
      const { data: prices } = await sb.from("v_fuel_station_latest").select("station_id, price_usd_per_gal").in("station_id", stationIds);
      prices?.forEach((r: any) => (priceMap[r.station_id] = Number(r.price_usd_per_gal)));
    }

    const mpg = Number((prof as any).base_mpg ?? 6.5), tank = Number((prof as any).tank_capacity_gal ?? 150), reserve = Number((prof as any).reserve_gal ?? 20);
    let fuel = Math.min(Number(payload.start_fuel_gal ?? tank), tank);
    const steps: any[] = []; let totalCost = 0, totalGal = 0;
    for (const leg of payload.route_legs) {
      const needed = leg.miles / mpg;
      if (fuel < needed + reserve) {
        const station = leg.station_id ?? null, price = station ? priceMap[station] ?? null : null;
        const buyGal = Math.min(tank - fuel, needed + reserve - fuel + 10);
        const cost = price ? buyGal * price : 0;
        fuel += buyGal; totalGal += buyGal; totalCost += cost;
        steps.push({ leg_index: leg.leg_index, action: "refuel", station_id: station, gallons: buyGal, price_per_gal: price });
      }
      fuel -= needed;
    }

    const { error } = await sb.from("fuel_refuel_plans").upsert({
      org_id: payload.org_id, load_id: payload.load_id, asset_id: payload.asset_id,
      total_cost_usd: totalCost, total_gallons: totalGal, details: steps,
      assumptions: { mpg, tank, reserve, start_fuel_gal: payload.start_fuel_gal ?? tank }
    } as any, { onConflict: "org_id,load_id" });
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true, totalCost, totalGal, stepsCount: steps.length, steps }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
};
Deno.serve(handler);
