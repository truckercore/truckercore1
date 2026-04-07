export type LatLng = { lat: number; lng: number };

// Stub for truck-safe routing. Replace with real GIS/OSRM/GraphHopper/Here/Google implementation.
export async function generateTruckSafeRoute(
  origin: LatLng,
  destination: LatLng,
  vehicle_specs: Record<string, unknown>,
  hazmat: boolean,
) {
  // Simulate processing time
  await new Promise((r) => setTimeout(r, 50));

  // Return a mock summary structure expected by the UI/backend
  return {
    origin,
    destination,
    distance_miles: 1234.5,
    eta_hours: 21.3,
    tolls_usd: 86.25,
    restrictions: {
      low_clearance: true,
      weight_limits: vehicle_specs["weight"] ? true : false,
      hazmat_restrictions: hazmat,
    },
    fuel_stops: [
      { name: "TA Exit 322", price: 4.09, poi_id: null },
      { name: "Pilot Exit 118", price: 4.15, poi_id: null },
    ],
    notes: "Mock truck-safe route. Replace with real provider.",
  };
}
