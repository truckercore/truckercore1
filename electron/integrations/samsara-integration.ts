import axios, { AxiosInstance } from 'axios';
import { ipcMain } from 'electron';

/**
 * Samsara Fleet Management API Integration
 * Docs: https://developers.samsara.com/
 *
 * Features:
 * - Real-time GPS tracking
 * - Driver HOS (Hours of Service)
 * - Vehicle diagnostics
 * - Fuel usage
 * - Harsh events (hard braking, acceleration)
 */

interface SamsaraConfig {
  apiKey: string;
  baseURL: string;
}

interface VehicleLocation {
  vehicleId: string;
  name: string;
  latitude: number;
  longitude: number;
  speed: number; // mph
  heading: number; // degrees
  address: string;
  timestamp: string;
}

interface DriverHOS {
  driverId: string;
  driverName: string;
  timeUntilBreak: number; // minutes
  driveTimeRemaining: number; // minutes
  shiftTimeRemaining: number; // minutes
  cycleTimeRemaining: number; // minutes
  violations: Array<{
    type: string;
    description: string;
    timestamp: string;
  }>;
}

interface VehicleDiagnostics {
  vehicleId: string;
  engineHours: number;
  odometer: number; // miles
  fuelLevel: number; // percentage
  engineRPM: number;
  engineTemperature: number; // fahrenheit
  oilPressure: number; // psi
  batteryVoltage: number;
  checkEngineLightOn: boolean;
  faultCodes: string[];
}

export class SamsaraIntegration {
  private client: AxiosInstance;
  private config: SamsaraConfig;

  constructor(config: SamsaraConfig) {
    this.config = config;

    this.client = axios.create({
      baseURL: config.baseURL || 'https://api.samsara.com',
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 30000,
    });

    this.setupHandlers();
  }

  private setupHandlers() {
    ipcMain.handle('samsara:get-vehicle-locations', async () => {
      return await this.getVehicleLocations();
    });

    ipcMain.handle('samsara:get-driver-hos', async (_event, driverId: string) => {
      return await this.getDriverHOS(driverId);
    });

    ipcMain.handle('samsara:get-vehicle-diagnostics', async (_event, vehicleId: string) => {
      return await this.getVehicleDiagnostics(vehicleId);
    });

    ipcMain.handle('samsara:get-harsh-events', async (_event, params: { startTime: string; endTime: string; vehicleIds?: string[] }) => {
      return await this.getHarshEvents(params);
    });

    ipcMain.handle('samsara:get-fuel-usage', async (_event, params: { startTime: string; endTime: string; vehicleIds?: string[] }) => {
      return await this.getFuelUsage(params);
    });
  }

  async getVehicleLocations(): Promise<VehicleLocation[]> {
    try {
      const response = await this.client.get('/fleet/vehicles/locations', { params: { types: 'current' } });
      return (response.data?.data || []).map((vehicle: any) => ({
        vehicleId: vehicle.id,
        name: vehicle.name,
        latitude: vehicle.location?.latitude,
        longitude: vehicle.location?.longitude,
        speed: this.metersPerSecondToMph(vehicle.location?.speedMilesPerHour || 0),
        heading: vehicle.location?.heading || 0,
        address: vehicle.location?.reverseGeo?.formattedLocation || 'Unknown',
        timestamp: vehicle.location?.time,
      }));
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Samsara get vehicle locations error:', error?.response?.data || error?.message);
      throw new Error(`Failed to get vehicle locations: ${error?.message || 'unknown error'}`);
    }
  }

  async getDriverHOS(driverId: string): Promise<DriverHOS> {
    try {
      const response = await this.client.get(`/fleet/drivers/${driverId}/hos_daily_logs`);
      const currentLog = response.data?.data?.[0] || {};
      return {
        driverId,
        driverName: currentLog.driver?.name || '',
        timeUntilBreak: this.millisToMinutes(currentLog.timeUntilBreak || 0),
        driveTimeRemaining: this.millisToMinutes(currentLog.driveRemaining || 0),
        shiftTimeRemaining: this.millisToMinutes(currentLog.shiftRemaining || 0),
        cycleTimeRemaining: this.millisToMinutes(currentLog.cycleRemaining || 0),
        violations: (currentLog.violations || []).map((v: any) => ({ type: v.type, description: v.description, timestamp: v.time })),
      };
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Samsara get driver HOS error:', error?.response?.data || error?.message);
      throw new Error(`Failed to get driver HOS: ${error?.message || 'unknown error'}`);
    }
  }

  async getVehicleDiagnostics(vehicleId: string): Promise<VehicleDiagnostics> {
    try {
      const response = await this.client.get(`/fleet/vehicles/${vehicleId}/diagnostics`);
      const data = response.data?.data?.[0] || {};
      return {
        vehicleId,
        engineHours: data.engineHours || 0,
        odometer: this.metersToMiles(data.odometerMeters || 0),
        fuelLevel: data.fuelPercent || 0,
        engineRPM: data.engineRpm || 0,
        engineTemperature: this.celsiusToFahrenheit(data.engineCoolantTemp || 0),
        oilPressure: data.oilPressure || 0,
        batteryVoltage: data.batteryMilliVolts ? data.batteryMilliVolts / 1000 : 0,
        checkEngineLightOn: !!data.checkEngineLight,
        faultCodes: data.faultCodes || [],
      };
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Samsara get vehicle diagnostics error:', error?.response?.data || error?.message);
      throw new Error(`Failed to get vehicle diagnostics: ${error?.message || 'unknown error'}`);
    }
  }

  async getHarshEvents(params: { startTime: string; endTime: string; vehicleIds?: string[] }): Promise<any[]> {
    try {
      const response = await this.client.get('/fleet/vehicles/harsh_event_logs', {
        params: { startTime: params.startTime, endTime: params.endTime, vehicleIds: params.vehicleIds?.join(',') },
      });
      return (response.data?.data || []).map((event: any) => ({
        eventId: event.id,
        vehicleId: event.vehicle?.id,
        vehicleName: event.vehicle?.name,
        driverId: event.driver?.id,
        driverName: event.driver?.name,
        type: event.harshEventType,
        severity: event.severity,
        location: {
          latitude: event.location?.latitude,
          longitude: event.location?.longitude,
          address: event.location?.reverseGeo?.formattedLocation,
        },
        timestamp: event.time,
        speed: this.metersPerSecondToMph(event.speedMilesPerHour || 0),
      }));
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Samsara get harsh events error:', error?.response?.data || error?.message);
      throw new Error(`Failed to get harsh events: ${error?.message || 'unknown error'}`);
    }
  }

  async getFuelUsage(params: { startTime: string; endTime: string; vehicleIds?: string[] }): Promise<any[]> {
    try {
      const response = await this.client.get('/fleet/vehicles/stats/fuel', {
        params: {
          startTime: params.startTime,
          endTime: params.endTime,
          vehicleIds: params.vehicleIds?.join(','),
          types: 'fuelUsed,fuelEconomy',
        },
      });
      return (response.data?.data || []).map((vehicle: any) => ({
        vehicleId: vehicle.id,
        vehicleName: vehicle.name,
        fuelUsed: this.litersToGallons(vehicle.fuelUsedLiters || 0),
        fuelEconomy: vehicle.fuelEconomyMpg || 0,
        distance: this.metersToMiles(vehicle.distanceMeters || 0),
        idleTime: this.millisToMinutes(vehicle.idleTime || 0),
      }));
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('Samsara get fuel usage error:', error?.response?.data || error?.message);
      throw new Error(`Failed to get fuel usage: ${error?.message || 'unknown error'}`);
    }
  }

  // Utility conversion methods
  private metersPerSecondToMph(mps: number): number {
    return Math.round(mps * 2.237);
  }
  private metersToMiles(meters: number): number {
    return Math.round(meters * 0.000621371);
  }
  private celsiusToFahrenheit(celsius: number): number {
    return Math.round((celsius * 9) / 5 + 32);
  }
  private millisToMinutes(millis: number): number {
    return Math.round(millis / 60000);
  }
  private litersToGallons(liters: number): number {
    return Math.round(liters * 0.264172 * 100) / 100;
  }
}
