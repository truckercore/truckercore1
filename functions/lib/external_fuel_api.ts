// Mock external fuel API client for local/testing usage.
// Replace with real integration logic to your provider.

export type FuelCardTransaction = {
  truck_vin?: string;
  truck_id?: string;
  driver_id?: string;
  gallons: number;
  total_cost: number;
  location?: string;
  fuel_time: string; // ISO timestamp
};

export async function fetchFuelCardData(): Promise<FuelCardTransaction[]> {
  // In production, call external API(s) and normalize to the shape above.
  // Example:
  // const resp = await fetch("https://provider/api/transactions", { headers: { Authorization: `Bearer ${API_KEY}` } });
  // const json = await resp.json();
  // return transform(json);

  // Stub data
  const now = new Date();
  return [
    {
      truck_vin: "1XKADP9X8CJ304XXX",
      gallons: 120.5,
      total_cost: 475.31,
      location: "TA Travel Center, Cheyenne WY",
      fuel_time: new Date(now.getTime() - 1000 * 60 * 60).toISOString(),
    },
  ];
}
