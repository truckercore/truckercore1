import axios, { AxiosInstance } from 'axios';
import { ipcMain } from 'electron';

interface MotiveConfig {
  apiKey: string;
  baseURL: string;
}

interface MotiveDriver {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  status: 'active' | 'inactive';
  licenseNumber: string;
  licenseState: string;
  hosStatus: {
    available_drive_time: number;
    available_shift_time: number;
    available_cycle_time: number;
    current_duty_status: string;
    time_until_break: number;
  };
}

export class MotiveIntegration {
  private client: AxiosInstance;
  private config: MotiveConfig;

  constructor(config: MotiveConfig) {
    this.config = config;
    this.client = axios.create({
      baseURL: config.baseURL || 'https://api.gomotive.com/v1',
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 30000,
    });
    this.setupHandlers();
  }

  private setupHandlers() {
    ipcMain.handle('motive:get-driver-hos', async (_event, driverId: string) => {
      return await this.getDriverHOS(driverId);
    });

    ipcMain.handle('motive:get-drivers', async () => {
      return await this.getDrivers();
    });

    ipcMain.handle('motive:get-dvir-reports', async (_event, params: { startDate: string; endDate: string; vehicleId?: string; }) => {
      return await this.getDVIRReports(params);
    });

    ipcMain.handle('motive:submit-dvir', async (_event, dvir: any) => {
      return await this.submitDVIR(dvir);
    });

    ipcMain.handle('motive:get-ifta-report', async (_event, params: { vehicleId: string; startDate: string; endDate: string; }) => {
      return await this.getIFTAReport(params);
    });

    ipcMain.handle('motive:get-vehicle-locations', async () => {
      return await this.getVehicleLocations();
    });

    ipcMain.handle('motive:get-eld-logs', async (_event, params: { driverId: string; date: string; }) => {
      return await this.getELDLogs(params);
    });
  }

  private async getDriverHOS(driverId: string): Promise<MotiveDriver> {
    const { data: driver } = await this.client.get(`/drivers/${driverId}`);
    return {
      id: driver.id,
      firstName: driver.first_name,
      lastName: driver.last_name,
      email: driver.email,
      phone: driver.phone_number,
      status: driver.status,
      licenseNumber: driver.license_number,
      licenseState: driver.license_state,
      hosStatus: driver.hos_status,
    };
  }

  private async getDrivers(): Promise<MotiveDriver[]> {
    const { data } = await this.client.get('/drivers');
    return (data.drivers || []).map((driver: any) => ({
      id: driver.id,
      firstName: driver.first_name,
      lastName: driver.last_name,
      email: driver.email,
      phone: driver.phone_number,
      status: driver.status,
      licenseNumber: driver.license_number,
      licenseState: driver.license_state,
      hosStatus: driver.hos_status,
    }));
  }

  private async getDVIRReports(params: { startDate: string; endDate: string; vehicleId?: string; }) {
    const { data } = await this.client.get('/dvir', { params: { start_date: params.startDate, end_date: params.endDate, vehicle_id: params.vehicleId } });
    return (data.dvirs || []).map((d: any) => ({
      id: d.id,
      driverId: d.driver_id,
      vehicleId: d.vehicle_id,
      timestamp: d.timestamp,
      status: d.status,
      defects: (d.defects || []).map((x: any) => ({ component: x.component, description: x.description, severity: x.severity })),
      signature: d.signature_url,
    }));
  }

  private async submitDVIR(dvir: any) {
    const { data } = await this.client.post('/dvir', {
      driver_id: dvir.driverId,
      vehicle_id: dvir.vehicleId,
      status: dvir.status,
      defects: dvir.defects,
      odometer: dvir.odometer,
      location: dvir.location,
      timestamp: new Date().toISOString(),
    });
    return { success: true, dvirId: data.id };
  }

  private async getIFTAReport(params: { vehicleId: string; startDate: string; endDate: string; }) {
    const { data: report } = await this.client.get('/ifta/report', { params: { vehicle_id: params.vehicleId, start_date: params.startDate, end_date: params.endDate } });
    return report;
  }

  private async getVehicleLocations() {
    const { data } = await this.client.get('/vehicles/locations');
    return (data.vehicles || []).map((v: any) => ({
      vehicleId: v.id,
      name: v.name,
      latitude: v.location.latitude,
      longitude: v.location.longitude,
      speed: v.location.speed,
      heading: v.location.heading,
      address: v.location.address,
      timestamp: v.location.timestamp,
      driverId: v.current_driver_id,
    }));
  }

  private async getELDLogs(params: { driverId: string; date: string; }) {
    const { data } = await this.client.get('/eld/logs', { params: { driver_id: params.driverId, date: params.date } });
    return data.logs;
  }
}
