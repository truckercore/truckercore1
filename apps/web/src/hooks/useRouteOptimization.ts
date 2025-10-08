import { useState, useCallback } from 'react';
import type { Location, Route } from '../types/fleet';
import { calculateDistance } from '../lib/fleet/mapUtils';

interface RouteOptimizationOptions {
  origin: Location;
  destination: Location;
  waypoints?: Location[];
  avoidTolls?: boolean;
  avoidHighways?: boolean;
  optimizeWaypoints?: boolean;
}

interface RouteOptimizationResult {
  route: Route;
  alternatives?: Route[];
  warnings?: string[];
}

export function useRouteOptimization() {
  const [isOptimizing, setIsOptimizing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const optimizeRoute = useCallback(async (options: RouteOptimizationOptions): Promise<RouteOptimizationResult> => {
    setIsOptimizing(true);
    setError(null);
    try {
      await new Promise((r) => setTimeout(r, 1000));
      const { origin, destination, waypoints = [] } = options;
      const totalDistance = calculateDistance(origin.lat!, origin.lng!, destination.lat!, destination.lng!);
      const path: [number, number][] = [ [origin.lng!, origin.lat!], ...waypoints.map((w) => [w.lng!, w.lat!] as [number, number]), [destination.lng!, destination.lat!] ];
      const estimatedDuration = (totalDistance / 50) * 60; // minutes @50mph
      const route: Route = {
        id: crypto.randomUUID(),
        origin,
        destination,
        waypoints,
        estimatedDistance: Math.round(totalDistance),
        estimatedDuration: Math.round(estimatedDuration),
        path,
        trafficLevel: Math.random() > 0.7 ? 'high' : Math.random() > 0.4 ? 'medium' : 'low',
        fuelCost: totalDistance * 0.35,
        createdAt: new Date(),
      } as Route;
      return { route };
    } catch (e: any) {
      const msg = e instanceof Error ? e.message : 'Failed to optimize route';
      setError(msg);
      throw e;
    } finally {
      setIsOptimizing(false);
    }
  }, []);

  const calculateMultiStopRoute = useCallback(async (stops: Location[]): Promise<RouteOptimizationResult> => {
    if (stops.length < 2) throw new Error('At least 2 stops are required');
    return optimizeRoute({ origin: stops[0], destination: stops[stops.length - 1], waypoints: stops.slice(1, -1), optimizeWaypoints: true });
  }, [optimizeRoute]);

  return { optimizeRoute, calculateMultiStopRoute, isOptimizing, error } as const;
}
