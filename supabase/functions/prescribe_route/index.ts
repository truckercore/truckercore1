import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { maybeFail } from "../_shared/fault.ts";
import { withMetrics } from "../_shared/metrics.ts";
import { withApiShape, ok, err } from "../_shared/http.ts";

type PrescribeInput = {
  language?: string;
  origin: { lat: number; lng: number };
  destination: { lat: number; lng: number };
  truck: { maxSpeed: number; weightKg: number; hazmat?: boolean };
  window?: { earliest?: string; latest?: string };
  constraints?: { avoidTolls?: boolean; avoidHighways?: boolean };
  context?: { trafficLevel?: string; weather?: string };
  notes?: string;
};

type PrescribeOutput = {
  departAt: string;
  targetSpeedMph: number;
  fuelStops: Array<{ lat: number; lng: number; reason: string }>;
  estimatedFuelCostUsd: number;
  eta: string;
  advisories: string[];
};

serve(withApiShape((req) => withMetrics('prescribe_route', async () => {
  if (req.method !== 'POST') return err('bad_request', 'Use POST', undefined, 405);
  await maybeFail();
  const input = await req.json() as PrescribeInput;
  const now = new Date();
  const depart = new Date(now.getTime() + 30*60*1000);
  const resp: PrescribeOutput = {
    departAt: depart.toISOString(),
    targetSpeedMph: Math.min(62, Math.round((input.truck?.maxSpeed ?? 65) - 3)),
    fuelStops: [{ lat: input.origin.lat + 0.5, lng: input.origin.lng + 0.5, reason: "Best price/clean restrooms" }],
    estimatedFuelCostUsd: 187.00,
    eta: new Date(depart.getTime() + 6.5*3600*1000).toISOString(),
    advisories: [
      input.language === 'es' ? "Evite las inspecciones cerca de la I-80" : "Avoid inspections near I-80",
      "Maintain steady speed to save ~8% fuel"
    ]
  };
  return ok(resp);
})));
