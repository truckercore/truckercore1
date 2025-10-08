import axios, { AxiosInstance } from 'axios';
import { ipcMain } from 'electron';

interface GeotabConfig {
  username: string;
  password: string;
  database: string;
  server: string;
}

interface GeotabSession {
  credentials: {
    database: string;
    sessionId: string;
    userName: string;
  };
}

export class GeotabIntegration {
  private client: AxiosInstance;
  private config: GeotabConfig;
  private session: GeotabSession | null = null;

  constructor(config: GeotabConfig) {
    this.config = config;
    this.client = axios.create({
      baseURL: `https://${config.server}/apiv1`,
      headers: { 'Content-Type': 'application/json' },
      timeout: 30000,
    });
    this.setupHandlers();
  }

  private setupHandlers() {
    ipcMain.handle('geotab:authenticate', async () => {
      return await this.authenticate();
    });
    ipcMain.handle('geotab:get-vehicles', async () => {
      return await this.getVehicles();
    });
    ipcMain.handle('geotab:get-diagnostics', async (_e, vehicleId: string) => {
      return await this.getVehicleDiagnostics(vehicleId);
    });
    ipcMain.handle('geotab:get-trip-history', async (_e, params: { vehicleId: string; startDate: string; endDate: string; }) => {
      return await this.getTripHistory(params);
    });
    ipcMain.handle('geotab:get-driver-scores', async (_e, driverId: string) => {
      return await this.getDriverScores(driverId);
    });
  }

  private async authenticate(): Promise<boolean> {
    const { data } = await this.client.post('', {
      method: 'Authenticate',
      params: {
        userName: this.config.username,
        password: this.config.password,
        database: this.config.database,
      },
    });
    if (data?.result?.credentials) {
      this.session = { credentials: data.result.credentials };
      return true;
    }
    throw new Error('Authentication failed');
  }

  private async apiCall(method: string, params: any = {}): Promise<any> {
    if (!this.session) {
      await this.authenticate();
    }
    try {
      const { data } = await this.client.post('', {
        method,
        params: { ...params, credentials: this.session!.credentials },
      });
      return data.result;
    } catch (error: any) {
      if (error?.response?.data?.error?.name === 'InvalidUserException') {
        await this.authenticate();
        return await this.apiCall(method, params);
      }
      throw error;
    }
  }

  private async getVehicles(): Promise<any[]> {
    const result = await this.apiCall('Get', { typeName: 'Device' });
    return result.map((d: any) => ({
      id: d.id,
      name: d.name,
      serialNumber: d.serialNumber,
      vehicleIdentificationNumber: d.vehicleIdentificationNumber,
      deviceType: d.deviceType,
      activeFrom: d.activeFrom,
      activeTo: d.activeTo,
    }));
  }

  private async getVehicleDiagnostics(vehicleId: string): Promise<any> {
    return await this.apiCall('Get', {
      typeName: 'StatusData',
      search: { deviceSearch: { id: vehicleId }, fromDate: new Date(Date.now() - 3600000).toISOString() },
    });
  }

  private async getTripHistory(params: { vehicleId: string; startDate: string; endDate: string; }): Promise<any[]> {
    const result = await this.apiCall('Get', {
      typeName: 'Trip',
      search: { deviceSearch: { id: params.vehicleId }, fromDate: params.startDate, toDate: params.endDate },
    });
    return result.map((trip: any) => ({
      id: trip.id,
      deviceId: trip.device.id,
      driverId: trip.driver?.id,
      startTime: trip.start,
      stopTime: trip.stop,
      distance: trip.distance,
      startLocation: { latitude: trip.startLocation.y, longitude: trip.startLocation.x },
      stopLocation: { latitude: trip.stopLocation.y, longitude: trip.stopLocation.x },
    }));
  }

  private async getDriverScores(driverId: string): Promise<any> {
    return await this.apiCall('Get', { typeName: 'DriverSafetyScore', search: { driverSearch: { id: driverId } } });
  }
}
