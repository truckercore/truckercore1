// TypeScript
import { useEffect } from "react";
import { planRoute, type Hazard } from "../lib/routing/riskAwareRouter";

export function useHazardAutoReroute(opts: {
  enabled: boolean;
  currentRoute: any;
  truck: any;
  hazards: Hazard[];
  onReroute: (r: any) => void;
}) {
  useEffect(() => {
    if (!opts.enabled || !opts.hazards?.length || !opts.currentRoute) return;
    (async () => {
      const alt = await planRoute(
        {
          origin: opts.currentRoute.origin,
          destination: opts.currentRoute.destination,
          waypoints: opts.currentRoute.waypoints,
          truck: opts.truck,
        },
        opts.hazards,
      );
      if (alt && alt.cost !== opts.currentRoute.cost) opts.onReroute(alt);
    })();
  }, [opts.enabled, JSON.stringify(opts.hazards), opts.currentRoute?.id]);
}
