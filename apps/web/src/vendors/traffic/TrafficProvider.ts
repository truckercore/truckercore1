// TypeScript
export interface TrafficProvider {
  name: string;
  slowdownAhead(lat: number, lng: number, km: number): Promise<{ deltaKph: number, distanceKm: number } | null>;
}

export class HereTraffic implements TrafficProvider {
  name = "here";
  async slowdownAhead(_lat: number, _lng: number, _km: number) {
    // TODO: implement HERE API lookup
    return { deltaKph: 35, distanceKm: 3.1 };
  }
}

export class CsvFallback implements TrafficProvider {
  name = "csv";
  async slowdownAhead() { return null; }
}

export class CanaryTraffic implements TrafficProvider {
  constructor(private primary: TrafficProvider, private secondary: TrafficProvider) {}
  async slowdownAhead(lat: number, lng: number, km: number) {
    try { return await this.primary.slowdownAhead(lat, lng, km); }
    catch { return await this.secondary.slowdownAhead(lat, lng, km); }
  }
}
