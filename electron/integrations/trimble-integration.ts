import axios, { AxiosInstance } from 'axios';
import { ipcMain } from 'electron';

/**
 * Trimble Maps API Integration
 * Docs: https://developer.trimblemaps.com/
 *
 * Features:
 * - Route optimization with truck restrictions
 * - Geocoding
 * - Traffic data
 * - Weather alerts
 * - Fuel prices along route
 */

interface TrimbleConfig {
  apiKey: string;
  baseURL: string;
}

interface TruckProfile {
  height: number; // feet
  width: number; // feet
  length: number; // feet
  weight: number; // pounds
  axles: number;
  hazmat: boolean;
}

interface RouteResult {
  distance: number; // miles
  duration: number; // minutes
  tollCost: number;
  fuelCost: number;
  route: Array<{ lat: number; lng: number }>;
  warnings: Array<{
    type: string;
    message: string;
    location: { lat: number; lng: number };
  }>;
  lowClearances: Array<{
    height: string;
    location: string;
    lat: number;
    lng: number;
  }>;
  weatherAlerts: Array<{
    severity: string;
    type: string;
    description: string;
    startTime: string;
    endTime: string;
  }>;
}

export class TrimbleIntegration {
  private client: AxiosInstance;
  private config: TrimbleConfig;

  constructor(config: TrimbleConfig) {
    this.config = config;

    this.client = axios.create({
      baseURL: config.baseURL || 'https://pcmiler.alk.com/apis/rest/v1.0',
      headers: {
        Authorization: `apikey ${config.apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 60000, // 60 seconds for route calculations
    });

    this.setupHandlers();
  }

  private setupHandlers() {
    ipcMain.handle('trimble:calculate-route', async (_event, params: {
      origin: string;
      destination: string;
      stops?: string[];
      truckProfile: TruckProfile;
      avoidTolls?: boolean;
      optimize?: boolean;
    }) => {
      return await this.calculateRoute(params);
    });

    ipcMain.handle('trimble:geocode', async (_event, address: string) => {
      return await this.geocode(address);
    });

    ipcMain.handle('trimble:reverse-geocode', async (_event, lat: number, lng: number) => {
      return await this.reverseGeocode(lat, lng);
    });

    ipcMain.handle('trimble:get-weather', async (_event, route: Array<{ lat: number; lng: number }>) => {
      return await this.getWeatherAlerts(route);
    });

    ipcMain.handle('trimble:find-fuel-stops', async (_event, params: {
      route: Array<{ lat: number; lng: number }>;
      maxDistance: number; // miles off route
    }) => {
      return await this.findFuelStops(params);
    });
  }

  async calculateRoute(params: {
    origin: string;
    destination: string;
    stops?: string[];
    truckProfile: TruckProfile;
    avoidTolls?: boolean;
    optimize?: boolean;
  }): Promise<RouteResult> {
    try {
      const stops = [params.origin, ...(params.stops || []), params.destination];

      const response = await this.client.post('/route/routeReports', {
        stops: stops.map((stop) => ({ Address: stop })),
        reportTypes: ['Mileage', 'State', 'Tolls', 'Route', 'Directions', 'Weather', 'LowClearances'],
        routeOptions: {
          vehicleType: 'Truck',
          routeOptimization: params.optimize ? 'Time' : 'None',
          highwayOnly: false,
          tollDiscourage: params.avoidTolls || false,
          borderOpen: true,
          classOverrides: {
            height: params.truckProfile.height.toString(),
            width: params.truckProfile.width.toString(),
            length: params.truckProfile.length.toString(),
            weight: params.truckProfile.weight.toString(),
            axles: params.truckProfile.axles.toString(),
            hazMat: params.truckProfile.hazmat ? 'General' : 'None',
          },
        },
        fuelOptions: {
          fuelPrice: 3.5,
          mpg: 6.5,
        },
      });

      const data = response.data || {};

      const route = this.extractRouteCoordinates(data);
      const warnings = this.extractWarnings(data);
      const lowClearances = this.extractLowClearances(data);
      const weatherAlerts = this.extractWeatherAlerts(data);

      return {
        distance: data.TMiles || 0,
        duration: data.TripTime || 0,
        tollCost: data.TollCost || 0,
        fuelCost: data.FuelCost || 0,
        route,
        warnings,
        lowClearances,
        weatherAlerts,
      };
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Trimble route calculation error:', error?.response?.data || error?.message);
      throw new Error(`Failed to calculate route: ${error?.message || 'unknown error'}`);
    }
  }

  async geocode(address: string): Promise<{ lat: number; lng: number; formattedAddress: string }> {
    try {
      const response = await this.client.get('/service/geocode', {
        params: { query: address, maxResults: 1 },
      });
      const result = response.data?.[0];
      if (!result) throw new Error('Address not found');
      return {
        lat: result.Coords.Lat,
        lng: result.Coords.Lon,
        formattedAddress:
          result.Address.StreetAddress + ', ' + result.Address.City + ', ' + result.Address.State + ' ' + result.Address.Zip,
      };
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Trimble geocode error:', error?.response?.data || error?.message);
      throw new Error(`Failed to geocode address: ${error?.message || 'unknown error'}`);
    }
  }

  async reverseGeocode(lat: number, lng: number): Promise<string> {
    try {
      const response = await this.client.get('/service/reverseGeocode', {
        params: { coords: `${lat},${lng}` },
      });
      const address = response.data?.Address || {};
      return `${address.StreetAddress}, ${address.City}, ${address.State} ${address.Zip}`;
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Trimble reverse geocode error:', error?.response?.data || error?.message);
      throw new Error(`Failed to reverse geocode: ${error?.message || 'unknown error'}`);
    }
  }

  async getWeatherAlerts(route: Array<{ lat: number; lng: number }>): Promise<any[]> {
    try {
      const samplePoints = this.sampleRoutePoints(route, 50);
      const alerts: any[] = [];
      for (const point of samplePoints) {
        const response = await this.client.get('/service/weather/alerts', {
          params: { latitude: point.lat, longitude: point.lng },
        });
        if (response.data?.alerts) alerts.push(...response.data.alerts);
      }
      return this.deduplicateAlerts(alerts);
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Trimble weather alerts error:', error?.response?.data || error?.message);
      return [];
    }
  }

  async findFuelStops(params: { route: Array<{ lat: number; lng: number }>; maxDistance: number }): Promise<any[]> {
    try {
      const samplePoints = this.sampleRoutePoints(params.route, 100);
      const fuelStops: any[] = [];
      for (const point of samplePoints) {
        const response = await this.client.get('/service/search', {
          params: { query: 'truck stop', latitude: point.lat, longitude: point.lng, radius: params.maxDistance, limit: 5 },
        });
        if (response.data?.results) fuelStops.push(...response.data.results);
      }
      return fuelStops;
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Trimble fuel stops error:', error?.response?.data || error?.message);
      return [];
    }
  }

  private extractRouteCoordinates(data: any): Array<{ lat: number; lng: number }> {
    const coords: Array<{ lat: number; lng: number }> = [];
    if (data?.RouteLegs) {
      data.RouteLegs.forEach((leg: any) => {
        if (leg.RouteDirections) {
          leg.RouteDirections.forEach((dir: any) => {
            if (dir.Coords) coords.push({ lat: dir.Coords.Lat, lng: dir.Coords.Lon });
          });
        }
      });
    }
    return coords;
  }

  private extractWarnings(data: any): Array<{ type: string; message: string; location: { lat: number; lng: number } }> {
    const warnings: Array<any> = [];
    if (data?.RouteLegs) {
      data.RouteLegs.forEach((leg: any) => {
        if (leg.Warnings) {
          leg.Warnings.forEach((warning: any) => {
            warnings.push({
              type: warning.Type,
              message: warning.Message,
              location: { lat: warning.Coords?.Lat || 0, lng: warning.Coords?.Lon || 0 },
            });
          });
        }
      });
    }
    return warnings;
  }

  private extractLowClearances(data: any): Array<{ height: string; location: string; lat: number; lng: number }> {
    const clearances: Array<any> = [];
    if (data?.LowClearances) {
      data.LowClearances.forEach((c: any) => {
        clearances.push({ height: c.Height, location: c.Location, lat: c.Coords.Lat, lng: c.Coords.Lon });
      });
    }
    return clearances;
  }

  private extractWeatherAlerts(data: any): Array<{ severity: string; type: string; description: string; startTime: string; endTime: string }> {
    const alerts: Array<any> = [];
    if (data?.WeatherAlerts) {
      data.WeatherAlerts.forEach((a: any) => {
        alerts.push({
          severity: a.Severity,
          type: a.Type,
          description: a.Description,
          startTime: a.StartTime,
          endTime: a.EndTime,
        });
      });
    }
    return alerts;
  }

  private sampleRoutePoints(route: Array<{ lat: number; lng: number }>, _intervalMiles: number): Array<{ lat: number; lng: number }> {
    if (!route || route.length <= 10) return route || [];
    const samples: Array<{ lat: number; lng: number }> = [route[0]];
    const step = Math.floor(route.length / 10);
    for (let i = step; i < route.length; i += step) samples.push(route[i]);
    samples.push(route[route.length - 1]);
    return samples;
  }

  private deduplicateAlerts(alerts: any[]): any[] {
    const seen = new Set<string>();
    return alerts.filter((alert: any) => {
      const key = `${alert.type}_${alert.startTime}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }
}
